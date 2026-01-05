#!/bin/bash

# MOVICUOTAS Mobile - Git Worktree Manager
# Helps manage multiple worktrees for parallel development

set -e

WORKTREES_DIR="../worktrees"
MAIN_BRANCH="main"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
    echo "MOVICUOTAS Mobile - Worktree Manager"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              - Show all worktrees"
    echo "  create <name>       - Create new worktree for branch <name>"
    echo "  remove <name>       - Remove worktree <name>"
    echo "  list                - List all worktrees with details"
    echo "  clean               - Remove all worktrees except main"
    echo "  help                - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 create feature/login-screen"
    echo "  $0 remove feature/login-screen"
}

show_status() {
    echo -e "${BLUE}=== Git Worktrees Status ===${NC}"
    echo ""

    worktree_count=$(git worktree list | wc -l | tr -d ' ')

    if [ "$worktree_count" -eq 1 ]; then
        echo -e "${YELLOW}Only main worktree exists${NC}"
        echo ""
        git worktree list
        echo ""
        echo -e "${GREEN}Tip:${NC} Create a new worktree with: $0 create <branch-name>"
    else
        git worktree list
        echo ""
        echo -e "${GREEN}Total worktrees:${NC} $worktree_count"
    fi
}

list_worktrees() {
    echo -e "${BLUE}=== Worktree Details ===${NC}"
    echo ""

    git worktree list --porcelain | awk '
        /^worktree / {
            if (path != "") {
                printf "📁 %s\n   Branch: %s\n   Commit: %s\n\n", path, branch, commit
            }
            path = substr($0, 10)
        }
        /^branch / { branch = substr($0, 8) }
        /^HEAD / { commit = substr($0, 6) }
        END {
            if (path != "") {
                printf "📁 %s\n   Branch: %s\n   Commit: %s\n", path, branch, commit
            }
        }
    '
}

create_worktree() {
    local branch_name=$1

    if [ -z "$branch_name" ]; then
        echo -e "${RED}Error: Branch name required${NC}"
        echo "Usage: $0 create <branch-name>"
        exit 1
    fi

    # Sanitize branch name for directory
    local dir_name=$(echo "$branch_name" | sed 's/\//-/g')
    local worktree_path="$WORKTREES_DIR/$dir_name"

    echo -e "${BLUE}Creating worktree...${NC}"
    echo "  Branch: $branch_name"
    echo "  Path: $worktree_path"
    echo ""

    # Check if branch exists
    if git show-ref --verify --quiet refs/heads/"$branch_name"; then
        echo -e "${YELLOW}Branch exists, checking out...${NC}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${GREEN}Creating new branch from $MAIN_BRANCH...${NC}"
        git worktree add -b "$branch_name" "$worktree_path" "$MAIN_BRANCH"
    fi

    echo ""
    echo -e "${GREEN}✓ Worktree created successfully!${NC}"
    echo ""
    echo "To start working:"
    echo "  cd $worktree_path"
}

remove_worktree() {
    local branch_name=$1

    if [ -z "$branch_name" ]; then
        echo -e "${RED}Error: Branch name required${NC}"
        echo "Usage: $0 remove <branch-name>"
        exit 1
    fi

    # Sanitize branch name for directory
    local dir_name=$(echo "$branch_name" | sed 's/\//-/g')
    local worktree_path="$WORKTREES_DIR/$dir_name"

    if [ ! -d "$worktree_path" ]; then
        echo -e "${RED}Error: Worktree not found at $worktree_path${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Removing worktree: $worktree_path${NC}"
    git worktree remove "$worktree_path"

    echo -e "${GREEN}✓ Worktree removed${NC}"

    # Ask if branch should be deleted
    echo ""
    read -p "Delete branch '$branch_name'? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git branch -d "$branch_name" 2>/dev/null && echo -e "${GREEN}✓ Branch deleted${NC}" || echo -e "${YELLOW}Branch not deleted (may have unmerged changes)${NC}"
    fi
}

clean_worktrees() {
    echo -e "${YELLOW}This will remove ALL worktrees except main${NC}"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi

    echo -e "${BLUE}Cleaning worktrees...${NC}"

    # Get current directory to return to it
    local current_dir=$(pwd)

    # Get list of worktrees (skip the first line which is the main worktree)
    git worktree list --porcelain | grep "^worktree " | awk '{print $2}' | tail -n +2 | while read -r path; do
        echo "Removing: $path"
        git worktree remove "$path" --force 2>/dev/null || true
    done

    cd "$current_dir"

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main command dispatcher
case "${1:-}" in
    status)
        show_status
        ;;
    list)
        list_worktrees
        ;;
    create)
        create_worktree "$2"
        ;;
    remove)
        remove_worktree "$2"
        ;;
    clean)
        clean_worktrees
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: ${1:-}${NC}"
        echo ""
        usage
        exit 1
        ;;
esac
