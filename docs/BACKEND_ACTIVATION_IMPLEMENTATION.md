# Implementación Backend: Activación de Dispositivos

## Resumen

Este documento describe cómo implementar el endpoint de activación de dispositivos en el backend Rails para MOVICUOTAS.

## Flujo de Activación

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUJO COMPLETO                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Admin crea préstamo → Se genera código de activación        │
│                                                                 │
│  2. Cliente recibe contrato con código (ej: "A1B2C3")           │
│                                                                 │
│  3. Cliente instala app → Ingresa código                        │
│                                                                 │
│  4. App envía: POST /api/v1/devices/activate                    │
│     {                                                           │
│       "activation_code": "A1B2C3",                              │
│       "fcm_token": "firebase_token...",                         │
│       "platform": "android",                                    │
│       "device_name": "Samsung Galaxy S21"                       │
│     }                                                           │
│                                                                 │
│  5. Backend valida código y registra dispositivo                │
│                                                                 │
│  6. Cliente hace login con Identidad + Contrato                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Migración: Agregar campos a `loans`

```ruby
# db/migrate/XXXXXX_add_activation_fields_to_loans.rb
class AddActivationFieldsToLoans < ActiveRecord::Migration[8.0]
  def change
    add_column :loans, :activation_code, :string, limit: 6
    add_column :loans, :activation_code_used, :boolean, default: false
    add_column :loans, :activated_at, :datetime
    add_column :loans, :activated_device_token, :string
    add_column :loans, :activated_platform, :string
    add_column :loans, :activated_device_name, :string

    add_index :loans, :activation_code, unique: true
  end
end
```

---

## 2. Migración Alternativa: Tabla separada `device_activations`

Si prefieres una tabla separada para mejor auditoría:

```ruby
# db/migrate/XXXXXX_create_device_activations.rb
class CreateDeviceActivations < ActiveRecord::Migration[8.0]
  def change
    create_table :device_activations do |t|
      t.references :loan, null: false, foreign_key: true
      t.string :activation_code, null: false, limit: 6
      t.string :fcm_token
      t.string :platform  # android, ios
      t.string :device_name
      t.string :status, default: 'pending'  # pending, activated, revoked
      t.datetime :activated_at
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :device_activations, :activation_code, unique: true
    add_index :device_activations, [:loan_id, :status]
  end
end
```

---

## 3. Modelo

```ruby
# app/models/device_activation.rb
class DeviceActivation < ApplicationRecord
  belongs_to :loan

  # Estados
  enum :status, {
    pending: 'pending',
    activated: 'activated',
    revoked: 'revoked'
  }

  # Validaciones
  validates :activation_code, presence: true, uniqueness: true, length: { is: 6 }
  validates :loan_id, presence: true

  # Scopes
  scope :active, -> { where(status: :activated) }
  scope :available, -> { where(status: :pending) }

  # Generar código único de 6 caracteres
  def self.generate_code
    # Caracteres sin ambiguos (sin 0/O, 1/I/L)
    chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
    loop do
      code = 6.times.map { chars[SecureRandom.random_number(chars.length)] }.join
      break code unless exists?(activation_code: code)
    end
  end

  # Activar dispositivo
  def activate!(fcm_token:, platform:, device_name:, ip_address: nil, user_agent: nil)
    return false if activated? || revoked?

    update!(
      status: :activated,
      fcm_token: fcm_token,
      platform: platform,
      device_name: device_name,
      activated_at: Time.current,
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  # Revocar activación (para re-activar en otro dispositivo)
  def revoke!
    update!(status: :revoked, fcm_token: nil)
  end
end
```

---

## 4. Actualizar Modelo Loan

```ruby
# app/models/loan.rb
class Loan < ApplicationRecord
  has_one :device_activation, dependent: :destroy

  # Callback para crear código de activación al crear préstamo
  after_create :create_activation_code

  def activated?
    device_activation&.activated?
  end

  def activation_code
    device_activation&.activation_code
  end

  private

  def create_activation_code
    DeviceActivation.create!(
      loan: self,
      activation_code: DeviceActivation.generate_code
    )
  end
end
```

---

## 5. Controller

```ruby
# app/controllers/api/v1/devices_controller.rb
module Api
  module V1
    class DevicesController < ApplicationController
      # NO requiere autenticación - es antes del login
      skip_before_action :authenticate_request

      # POST /api/v1/devices/activate
      def activate
        # Validar parámetros requeridos
        unless params[:fcm_token].present?
          return render json: { error: 'Token FCM requerido' }, status: :bad_request
        end

        unless params[:activation_code].present?
          return render json: { error: 'Código de activación requerido' }, status: :bad_request
        end

        # Buscar activación por código
        activation = DeviceActivation.find_by(
          activation_code: params[:activation_code].upcase.strip
        )

        # Código no existe
        unless activation
          return render json: { error: 'Código de activación inválido' }, status: :not_found
        end

        # Código ya fue usado
        if activation.activated?
          return render json: { error: 'Este código ya fue activado' }, status: :unprocessable_entity
        end

        # Código fue revocado
        if activation.revoked?
          return render json: { error: 'Este código fue revocado. Contacte a su tienda.' }, status: :unprocessable_entity
        end

        # Activar dispositivo
        activation.activate!(
          fcm_token: params[:fcm_token],
          platform: params[:platform] || 'unknown',
          device_name: params[:device_name] || 'Unknown Device',
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )

        render json: {
          message: 'Dispositivo activado correctamente',
          loan_id: activation.loan_id
        }, status: :ok

      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    end
  end
end
```

---

## 6. Rutas

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Activación de dispositivos (sin auth)
      post 'devices/activate', to: 'devices#activate'

      # ... otras rutas
    end
  end
end
```

---

## 7. Respuestas del Endpoint

### Éxito (200 OK)
```json
{
  "message": "Dispositivo activado correctamente",
  "loan_id": 123
}
```

### Error: Token FCM faltante (400 Bad Request)
```json
{
  "error": "Token FCM requerido"
}
```

### Error: Código inválido (404 Not Found)
```json
{
  "error": "Código de activación inválido"
}
```

### Error: Código ya usado (422 Unprocessable Entity)
```json
{
  "error": "Este código ya fue activado"
}
```

### Error: Código revocado (422 Unprocessable Entity)
```json
{
  "error": "Este código fue revocado. Contacte a su tienda."
}
```

---

## 8. Request de la App

```
POST /api/v1/devices/activate
Content-Type: application/json

{
  "activation_code": "A1B2C3",
  "fcm_token": "fMxYz123...muy_largo...abc",
  "platform": "android",
  "device_name": "Samsung Galaxy S21"
}
```

---

## 9. Mostrar Código en Contrato (Admin)

Cuando generes el contrato PDF, incluye el código de activación:

```ruby
# En el servicio de generación de PDF del contrato
def generate_contract_pdf(loan)
  # ... otros datos del contrato ...

  pdf.text "CÓDIGO DE ACTIVACIÓN DE APP"
  pdf.text loan.activation_code, size: 24, style: :bold
  pdf.text "Ingrese este código en la app MOVICUOTAS para activar su cuenta"
end
```

---

## 10. Panel Admin: Ver Activaciones

```ruby
# app/controllers/admin/device_activations_controller.rb
module Admin
  class DeviceActivationsController < AdminController
    def index
      @activations = DeviceActivation.includes(:loan)
                                     .order(created_at: :desc)
                                     .page(params[:page])
    end

    def revoke
      activation = DeviceActivation.find(params[:id])
      activation.revoke!
      redirect_to admin_device_activations_path, notice: 'Activación revocada'
    end

    def regenerate
      activation = DeviceActivation.find(params[:id])
      activation.update!(
        activation_code: DeviceActivation.generate_code,
        status: :pending,
        fcm_token: nil,
        activated_at: nil
      )
      redirect_to admin_device_activations_path, notice: 'Nuevo código generado'
    end
  end
end
```

---

## 11. Vista Admin (ejemplo básico)

```erb
<!-- app/views/admin/device_activations/index.html.erb -->
<table>
  <thead>
    <tr>
      <th>Contrato</th>
      <th>Cliente</th>
      <th>Código</th>
      <th>Estado</th>
      <th>Dispositivo</th>
      <th>Activado</th>
      <th>Acciones</th>
    </tr>
  </thead>
  <tbody>
    <% @activations.each do |activation| %>
      <tr>
        <td><%= activation.loan.contract_number %></td>
        <td><%= activation.loan.customer.full_name %></td>
        <td><code><%= activation.activation_code %></code></td>
        <td>
          <% case activation.status %>
          <% when 'pending' %>
            <span class="badge bg-warning">Pendiente</span>
          <% when 'activated' %>
            <span class="badge bg-success">Activado</span>
          <% when 'revoked' %>
            <span class="badge bg-danger">Revocado</span>
          <% end %>
        </td>
        <td><%= activation.device_name %> (<%= activation.platform %>)</td>
        <td><%= activation.activated_at&.strftime('%d/%m/%Y %H:%M') || '-' %></td>
        <td>
          <% if activation.activated? %>
            <%= button_to 'Revocar', revoke_admin_device_activation_path(activation),
                method: :post, class: 'btn btn-sm btn-danger',
                data: { confirm: '¿Revocar activación?' } %>
          <% else %>
            <%= button_to 'Regenerar', regenerate_admin_device_activation_path(activation),
                method: :post, class: 'btn btn-sm btn-warning' %>
          <% end %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

---

## 12. Seed para Testing

```ruby
# db/seeds.rb

# Crear activación de prueba
loan = Loan.first
if loan && !loan.device_activation
  DeviceActivation.create!(
    loan: loan,
    activation_code: 'TEST01'
  )
  puts "Código de prueba creado: TEST01"
end
```

---

## Resumen de Archivos a Crear/Modificar

| Archivo | Acción |
|---------|--------|
| `db/migrate/xxx_create_device_activations.rb` | Crear |
| `app/models/device_activation.rb` | Crear |
| `app/models/loan.rb` | Modificar (agregar asociación) |
| `app/controllers/api/v1/devices_controller.rb` | Crear |
| `config/routes.rb` | Modificar (agregar ruta) |
| `app/controllers/admin/device_activations_controller.rb` | Crear (opcional) |
| `app/views/admin/device_activations/index.html.erb` | Crear (opcional) |

---

## Comandos para Implementar

```bash
# 1. Generar migración
rails generate migration CreateDeviceActivations

# 2. Editar migración con el código de arriba

# 3. Ejecutar migración
rails db:migrate

# 4. Crear modelo y controller

# 5. Agregar ruta

# 6. Probar con curl
curl -X POST http://localhost:3000/api/v1/devices/activate \
  -H "Content-Type: application/json" \
  -d '{
    "activation_code": "TEST01",
    "fcm_token": "test_token_123",
    "platform": "android",
    "device_name": "Test Device"
  }'
```

---

## Notas de Seguridad

1. **Rate Limiting**: Implementar límite de intentos por IP para evitar fuerza bruta
2. **Códigos únicos**: Usar caracteres sin ambiguos (sin 0/O, 1/I/L)
3. **Expiración opcional**: Puedes agregar `expires_at` si quieres que los códigos expiren
4. **Logs de auditoría**: Guardar IP y User-Agent para detectar fraudes
5. **Notificación admin**: Enviar email cuando se active un dispositivo (opcional)
