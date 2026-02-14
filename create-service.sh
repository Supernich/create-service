#!/bin/bash

# Systemd Service Creator Script with Template Support
# Usage: ./create-service.sh
# Creator: https://github.com/Supernich
# Generated using DeepSeek

set -e  # Exit on error

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default template URL (change this to your GitHub raw URL)
DEFAULT_TEMPLATE_URL="https://raw.githubusercontent.com/Supernich/create-service/main/service_template.service"

echo -e "${BLUE}╔══════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Systemd Service Creator      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════╝${NC}"
echo ""

# Function to prompt for input with default value
prompt() {
    local prompt_text=$1
    local default_value=$2
    local input
    
    if [ -n "$default_value" ]; then
        read -p "$prompt_text [$default_value]: " input
        # If empty input, use default
        if [ -z "$input" ]; then
            echo "$default_value"
        else
            echo "$input"
        fi
    else
        # No default - require non-empty input
        while true; do
            read -p "$prompt_text: " input
            if [ -n "$input" ]; then
                echo "$input"
                break
            else
                echo "Error: Value cannot be empty. Please provide a value." >&2
            fi
        done
    fi
}

# Function to prompt yes/no with default
prompt_yes_no() {
    local prompt_text=$1
    local default_value=$2
    local input
    
    while true; do
        if [ "$default_value" = "y" ]; then
            read -p "$prompt_text [Y/n]: " input
        else
            read -p "$prompt_text [y/N]: " input
        fi
        
        if [ -z "$input" ]; then
            if [ "$default_value" = "y" ]; then
                return 0
            else
                return 1
            fi
        fi
        
        case ${input,,} in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer yes or no" ;;
        esac
    done
}

# Function to prompt for security options
prompt_security_options() {
    local security_options=""
    
    if prompt_yes_no "Enable NoNewPrivileges (prevents privilege escalation)?" "y"; then
        security_options="${security_options}NoNewPrivileges=yes\n"
        echo -e "${GREEN}  ✓ ${NC}NoNewPrivileges enabled${NC}"
    else
        echo -e "${YELLOW}  ✗ ${NC}NoNewPrivileges disabled${NC}"
    fi
    
    if prompt_yes_no "Enable PrivateTmp (isolated temporary directory)?" "y"; then
        security_options="${security_options}PrivateTmp=yes\n"
        echo -e "${GREEN}  ✓ ${NC}PrivateTmp enabled${NC}"
    else
        echo -e "${YELLOW}  ✗ ${NC}PrivateTmp disabled${NC}"
    fi
    
    if prompt_yes_no "Enable ProtectSystem=full (protects /usr, /boot, /etc)?" "y"; then
        security_options="${security_options}ProtectSystem=full\n"
        echo -e "${GREEN}  ✓ ${NC}ProtectSystem=full enabled${NC}"
    else
        echo -e "${YELLOW}  ✗ ${NC}ProtectSystem=full disabled${NC}"
    fi
    
    if prompt_yes_no "Enable ProtectHome=yes (isolates /home and /root)?" "y"; then
        security_options="${security_options}ProtectHome=yes\n"
        echo -e "${GREEN}  ✓ ${NC}ProtectHome=yes enabled${NC}"
    else
        echo -e "${YELLOW}  ✗ ${NC}ProtectHome=yes disabled${NC}"
    fi
    
    echo "$security_options"
}

# Check sudo access
check_sudo() {
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Sudo access available${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} No passwordless sudo access. Some operations may require password.${NC}"
        if sudo -v 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Sudo access granted${NC}"
            return 0
        else
            echo -e "${RED}✗${NC} No sudo access available. Limited functionality.${NC}"
            return 1
        fi
    fi
}

# Function to validate directory exists
validate_dir() {
    local dir=$1
    
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}Warning: Directory $dir does not exist.${NC}"
        if prompt_yes_no "Create it?" "y"; then
            mkdir -p "$dir"
            echo -e "${GREEN}✓${NC} Directory created: $dir${NC}"
        else
            echo -e "${RED}✗${NC} Directory must exist to continue. Exiting.${NC}"
            exit 1
        fi
    fi
}

# Function to replace placeholders in template
replace_placeholders() {
    local template_file=$1
    local output_file=$2
    local description=$3
    local working_dir=$4
    local username=$5
    local groupname=$6
    local security_options=$7
    local restart_policy=$8
    local start_command=$9
    local stop_command=${10}
    
    # Copy template to output file
    cp "$template_file" "$output_file"
    
    # Replace placeholders
    sed -i "s|__DESCRIPTION__|$description|g" "$output_file"
    sed -i "s|__WORKING_DIR__|$working_dir|g" "$output_file"
    sed -i "s|__USERNAME__|$username|g" "$output_file"
    sed -i "s|__GROUPNAME__|$groupname|g" "$output_file"
    sed -i "s|__RESTART_POLICY__|$restart_policy|g" "$output_file"
    
    # Escape and insert start command
    local escaped_start=$(printf '%s\n' "$start_command" | sed -e 's/[\/&]/\\&/g' -e 's/"/\\"/g')
    sed -i "s|__START_COMMAND__|$escaped_start|g" "$output_file"
    
    # Handle stop command
    if [ -n "$stop_command" ]; then
        local escaped_stop=$(printf '%s\n' "$stop_command" | sed -e 's/[\/&]/\\&/g' -e 's/"/\\"/g')
        sed -i "s|__STOP_COMMAND_LINE__|ExecStop=$escaped_stop|g" "$output_file"
    else
        sed -i "s|__STOP_COMMAND_LINE__||g" "$output_file"
    fi
    
    # Handle security options LAST (they contain only simple key=value lines)
    if [ -n "$security_options" ]; then
        # Simple escape for security options (they shouldn't have complex chars)
        local escaped_opts=$(printf '%s\n' "$security_options" | sed 's/[\/&]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')
        sed -i "s|__SECURITY_OPTIONS__|$escaped_opts|g" "$output_file"
    else
        sed -i "/__SECURITY_OPTIONS__/d" "$output_file"
    fi
}

# Check sudo status
HAS_SUDO=false
if check_sudo; then
    HAS_SUDO=true
fi
echo ""

# Template download
echo ""
echo -e "${YELLOW}Downloading template from GitHub...${NC}"

# Create temp file
TEMP_TEMPLATE=$(mktemp)

# Check for curl or wget installation
if command -v curl &> /dev/null; then
    if ! curl -s -f "$DEFAULT_TEMPLATE_URL" -o "$TEMP_TEMPLATE"; then
        echo -e "${RED}✗${NC} Failed to download template from $DEFAULT_TEMPLATE_URL${NC}"
        rm -f "$TEMP_TEMPLATE"
        exit 1
    fi
elif command -v wget &> /dev/null; then
    if ! wget -q "$DEFAULT_TEMPLATE_URL" -O "$TEMP_TEMPLATE"; then
        echo -e "${RED}✗${NC} Failed to download template from $DEFAULT_TEMPLATE_URL${NC}"
        rm -f "$TEMP_TEMPLATE"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Neither curl nor wget found. Please install one.${NC}"
    rm -f "$TEMP_TEMPLATE"
    exit 1
fi

# Check file not empty
if [ ! -s "$TEMP_TEMPLATE" ]; then
    echo -e "${RED}✗${NC} Downloaded template is empty${NC}"
    rm -f "$TEMP_TEMPLATE"
    exit 1
fi

TEMPLATE_FILE="$TEMP_TEMPLATE"
echo -e "${GREEN}✓${NC} Template downloaded successfully${NC}"

# Show template content
echo ""
echo -e "${YELLOW}Template content:${NC}"
echo "------------------------------------------------"
cat "$TEMPLATE_FILE"
echo "------------------------------------------------"
echo ""

# Gather service information
echo -e "${YELLOW}Please provide the following service information:${NC}"
echo "------------------------------------------------"

SERVICE_NAME=$(prompt "Service name" "")
SERVICE_DESCRIPTION=$(prompt "Description" "Custom service")
WORKING_DIR=$(prompt "Working directory" "$(pwd)")
USERNAME=$(prompt "Username" "$USER")

if prompt_yes_no "Use custom group (different from username)?" "n"; then
    GROUPNAME=$(prompt "Group name" "$USERNAME")
else
    GROUPNAME="$USERNAME"
fi

# Get security options
echo ""
echo -e "${YELLOW}Security hardening options:${NC}"
echo "These options add extra security but may cause issues with some applications."
echo ""
SECURITY_OPTIONS=""

if prompt_yes_no "Enable NoNewPrivileges (prevents privilege escalation)?" "y"; then
    SECURITY_OPTIONS="${SECURITY_OPTIONS}NoNewPrivileges=yes\n"
    echo -e "${GREEN}  ✓ ${NC}NoNewPrivileges enabled${NC}"
else
    echo -e "${YELLOW}  ✗ ${NC}NoNewPrivileges disabled${NC}"
fi

if prompt_yes_no "Enable PrivateTmp (isolated temporary directory)?" "y"; then
    SECURITY_OPTIONS="${SECURITY_OPTIONS}PrivateTmp=yes\n"
    echo -e "${GREEN}  ✓ ${NC}PrivateTmp enabled${NC}"
else
    echo -e "${YELLOW}  ✗ ${NC}PrivateTmp disabled${NC}"
fi

if prompt_yes_no "Enable ProtectSystem=full (protects /usr, /boot, /etc)?" "y"; then
    SECURITY_OPTIONS="${SECURITY_OPTIONS}ProtectSystem=full\n"
    echo -e "${GREEN}  ✓ ${NC}ProtectSystem=full enabled${NC}"
else
    echo -e "${YELLOW}  ✗ ${NC}ProtectSystem=full disabled${NC}"
fi

if prompt_yes_no "Enable ProtectHome=yes (isolates /home and /root)?" "y"; then
    SECURITY_OPTIONS="${SECURITY_OPTIONS}ProtectHome=yes\n"
    echo -e "${GREEN}  ✓ ${NC}ProtectHome=yes enabled${NC}"
else
    echo -e "${YELLOW}  ✗ ${NC}ProtectHome=yes disabled${NC}"
fi
echo ""

echo -e "${YELLOW}Select restart policy:${NC}"
echo "1) on-failure - Restart only if service crashes (recommended for game servers)"
echo "2) always - Always restart, even if stopped cleanly (use with caution)"
echo "3) no - Never restart automatically"
echo "4) on-abnormal - Restart on abnormal termination"
while true; do
    read -p "Choose policy [1-4] (1): " choice
    choice=${choice:-1}
    case $choice in
        1) RESTART_POLICY="on-failure"; break;;
        2) RESTART_POLICY="always"; break;;
        3) RESTART_POLICY="no"; break;;
        4) RESTART_POLICY="on-abnormal"; break;;
        *) echo "Please enter 1, 2, 3, or 4";;
    esac
done

# Ask about screen usage
echo ""
USE_SCREEN=$(prompt_yes_no "Use screen to run this service?" "y")

if [ "$USE_SCREEN" = true ]; then
    SCREEN_NAME=$(prompt "Screen session name" "$SERVICE_NAME")
    echo -e "${YELLOW}Enter the command to run INSIDE screen (without screen prefix):${NC}"
    BASE_START_COMMAND=$(prompt "Base command" "")
    START_COMMAND=$("/usr/bin/screen -dmS $SCREEN_NAME $BASE_START_COMMAND")
    
    # For stop command, offer screen-friendly option
    echo ""
    if prompt_yes_no "Use screen-friendly stop command (recommended)?" "y"; then
        BASE_STOP_COMMAND=$(prompt "Base stop command" "")
        STOP_COMMAND=$("/usr/bin/screen -p 0 -S $SCREEN_NAME -X eval 'stuff \"$BASE_STOP_COMMAND\015\"'")
        echo -e "${GREEN}✓${NC} Using screen stop command: $STOP_COMMAND${NC}"
    else
        STOP_COMMAND=$(prompt "Custom stop command" "")
    fi
else
    START_COMMAND=$(prompt "Start command" "")
    STOP_COMMAND=$(prompt "Stop command" "")
fi

# Validate working directory
validate_dir "$WORKING_DIR"

# Confirm information
echo ""
echo -e "${YELLOW}Service configuration:${NC}"
echo "  Name:          $SERVICE_NAME"
echo "  Description:   $SERVICE_DESCRIPTION"
echo "  Working dir:   $WORKING_DIR"
echo "  User:          $USERNAME"
echo "  Security:"
if [ -n "$SECURITY_OPTIONS" ]; then
    echo "$SECURITY_OPTIONS" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "    $line"
        fi
    done
else
    echo "    No security options enabled"
fi
echo "  Restart policy: $RESTART_POLICY"
if [ "$USE_SCREEN" = true ]; then
    echo "  Screen:        yes (session: $SCREEN_NAME)"
fi
echo "  Start cmd:     $START_COMMAND"
if [ -n "$STOP_COMMAND" ]; then
    echo "  Stop cmd:      $STOP_COMMAND"
else
    echo "  Stop cmd:      (none - using SIGTERM)"
fi
echo ""

if ! prompt_yes_no "Is this correct?" "y"; then
    echo -e "${RED}Exiting. Please run again.${NC}"
    # Clean up temp file
    [ -f "$TEMP_TEMPLATE" ] && rm -f "$TEMP_TEMPLATE"
    exit 0
fi

# Ask where to save the service file
echo ""
echo -e "${YELLOW}Where should the service file be saved?${NC}"
SAVE_LOCATION=$(prompt "Save location (press Enter for current directory)" ".")

# Create the service file from template
SERVICE_FILE="$SAVE_LOCATION/$SERVICE_NAME.service"
replace_placeholders "$TEMPLATE_FILE" "$SERVICE_FILE" \
    "$SERVICE_DESCRIPTION" \
    "$WORKING_DIR" \
    "$USERNAME" \
    "$GROUPNAME" \
    "$SECURITY_OPTIONS" \
    "$RESTART_POLICY" \
    "$START_COMMAND" \
    "$STOP_COMMAND"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Service file created: $SERVICE_FILE${NC}"
else
    echo -e "${RED}✗${NC} Failed to create service file${NC}"
    # Clean up temp file
    [ -f "$TEMP_TEMPLATE" ] && rm -f "$TEMP_TEMPLATE"
    exit 1
fi

# Show the created file
echo ""
echo -e "${YELLOW}Created service file content:${NC}"
echo "------------------------------------------------"
cat "$SERVICE_FILE"
echo "------------------------------------------------"

# System-level operations (only if sudo available)
if [ "$HAS_SUDO" = true ]; then
    # Ask how to install to systemd
    echo ""
    echo -e "${YELLOW}How would you like to install this service to systemd?${NC}"
    echo "1) Create symbolic link (recommended)"
    echo "2) Copy file directly"
    echo "3) Skip installation (just create file)"
    
    INSTALL_CHOICE=$(prompt "Choose option [1-3]" "1")
    
    case $INSTALL_CHOICE in
        1)
            echo -e "${YELLOW}Creating symbolic link...${NC}"
            sudo ln -sf "$(realpath "$SERVICE_FILE")" "/etc/systemd/system/$SERVICE_NAME.service"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓${NC} Symbolic link created${NC}"
            else
                echo -e "${RED}✗${NC} Failed to create symbolic link${NC}"
                exit 1
            fi
            ;;
        2)
            echo -e "${YELLOW}Copying file to systemd directory...${NC}"
            sudo cp "$SERVICE_FILE" "/etc/systemd/system/"
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓${NC} File copied successfully${NC}"
            else
                echo -e "${RED}✗${NC} Failed to copy file${NC}"
                exit 1
            fi
            ;;
        3)
            echo -e "${YELLOW}Skipping installation. Service file saved at: $SERVICE_FILE${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Exiting.${NC}"
            exit 1
            ;;
    esac
    
    # Ask if systemd reload is needed
    echo ""
    if prompt_yes_no "Reload systemd to apply changes?" "y"; then
        echo -e "${YELLOW}Reloading systemd...${NC}"
        sudo systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Systemd reloaded${NC}"
    fi
    
    # Ask to enable and start the service
    echo ""
    if prompt_yes_no "Enable service to start at boot?" "y"; then
        sudo systemctl enable "$SERVICE_NAME.service"
        echo -e "${GREEN}✓${NC} Service enabled${NC}"
    fi
    
    if prompt_yes_no "Start service now?" "y"; then
        sudo systemctl start "$SERVICE_NAME.service"
        echo -e "${GREEN}✓${NC} Service started${NC}"
        
        # Show status
        echo ""
        echo -e "${YELLOW}Service status:${NC}"
        sudo systemctl status "$SERVICE_NAME.service" --no-pager
    fi
else
    echo ""
    echo -e "${YELLOW}No sudo access. Skipping systemd installation.${NC}"
    echo -e "To install manually:"
    echo "  sudo cp $SERVICE_FILE /etc/systemd/system/"
    echo "  OR"
    echo "  sudo ln -sf $(realpath "$SERVICE_FILE") /etc/systemd/system/$SERVICE_NAME.service"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable $SERVICE_NAME"
    echo "  sudo systemctl start $SERVICE_NAME"
fi

echo ""
echo -e "${GREEN}✓${NC} Service setup complete!${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "  sudo ln -sf $(realpath "$SERVICE_FILE") /etc/systemd/system/$SERVICE_NAME.service # Create SymLink from file to systemd"
echo "  sudo rm /etc/systemd/system/$SERVICE_NAME.service # Remove SymLink from systemd"
echo ""
echo "  sudo systemctl status $SERVICE_NAME # Check service status"
echo "  sudo journalctl -u $SERVICE_NAME -f # View logs"
echo ""
echo "  sudo systemctl ebanble $SERVICE_NAME # Enable service"
echo "  sudo systemctl disable $SERVICE_NAME # Disable service"
echo "  sudo systemctl start $SERVICE_NAME # Start service"
echo "  sudo systemctl restart $SERVICE_NAME # Restart service"
echo "  sudo systemctl stop $SERVICE_NAME # Stop service"

# If screen is being used, show screen note
if [ "$USE_SCREEN" = true ]; then
    echo ""
    echo -e "${YELLOW}Screen session information:${NC}"
    echo "  Session name: $SCREEN_NAME"
    echo "  To attach:    screen -r $SCREEN_NAME"
    echo "  To detach:    Ctrl+A then D"
    echo "  To list:      screen -ls"
fi
