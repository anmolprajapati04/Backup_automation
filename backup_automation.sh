#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please run with sudo."
    exit 1
fi

CONFIG_FILE="/etc/backup_automation.conf"
LOG_FILE="/var/log/backup_automation.log"

# Globals to store user input
SOURCE_DIR=""
DEST_DIR=""
FREQUENCY=""

# Handle auto-mode (cron)
if [ "$1" == "start_backup" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        BACKUP_NAME="backup_$(date +%F_%H-%M-%S).tar.gz"
        mkdir -p "$DEST_DIR"
        tar -czf "$DEST_DIR/$BACKUP_NAME" -C "$SOURCE_DIR" . 2>>"$LOG_FILE"
        echo "$(date) - [AUTO] Backup created: $DEST_DIR/$BACKUP_NAME" >> "$LOG_FILE"
        exit 0
    else
        echo "$(date) - [ERROR] Config file not found for automated backup." >> "$LOG_FILE"
        exit 1
    fi
fi

# Display the menu
show_menu() {
    CHOICE=$(dialog --backtitle "Backup Automation" --title "Backup Options" --menu "Select an option" 15 50 6 \
        1 "Select Source Folder" \
        2 "Select Destination Folder" \
        3 "Select Backup Frequency" \
        4 "Start Backup Now" \
        5 "Exit" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) select_source_folder ;;
        2) select_destination_folder ;;
        3) select_backup_frequency ;;
        4) start_backup ;;
        5) clear; exit 0 ;;
        *) show_menu ;;
    esac
}

select_source_folder() {
    SOURCE_DIR=$(dialog --title "Select Source Folder" --fselect /home/ 15 50 3>&1 1>&2 2>&3)
    if [ -z "$SOURCE_DIR" ]; then
        dialog --msgbox "No source folder selected." 6 40
    else
        dialog --msgbox "Source set to: $SOURCE_DIR" 6 50
    fi
    show_menu
}

select_destination_folder() {
    DEST_DIR=$(dialog --title "Select Destination Folder" --fselect /home/ 15 50 3>&1 1>&2 2>&3)
    if [ -z "$DEST_DIR" ]; then
        dialog --msgbox "No destination folder selected." 6 40
    else
        mkdir -p "$DEST_DIR"
        dialog --msgbox "Destination set to: $DEST_DIR" 6 50
    fi
    show_menu
}

select_backup_frequency() {
    CHOICE=$(dialog --title "Backup Frequency" --menu "How often to back up?" 15 50 3 \
        1 "Daily" \
        2 "Weekly" \
        3 "Monthly" 3>&1 1>&2 2>&3)

    case $CHOICE in
        1) FREQUENCY="daily" ;;
        2) FREQUENCY="weekly" ;;
        3) FREQUENCY="monthly" ;;
        *) FREQUENCY="daily" ;;
    esac
    dialog --msgbox "Frequency set to: $FREQUENCY" 6 40
    show_menu
}

start_backup() {
    if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ]; then
        dialog --msgbox "Both source and destination must be set first!" 6 50
        show_menu
        return
    fi

    # Save config for cron jobs
    echo "SOURCE_DIR=\"$SOURCE_DIR\"" > "$CONFIG_FILE"
    echo "DEST_DIR=\"$DEST_DIR\"" >> "$CONFIG_FILE"

    BACKUP_NAME="backup_$(date +%F_%H-%M-%S).tar.gz"
    mkdir -p "$DEST_DIR"
    tar -czf "$DEST_DIR/$BACKUP_NAME" -C "$SOURCE_DIR" . 2>>"$LOG_FILE"
    echo "$(date) - Manual Backup created: $DEST_DIR/$BACKUP_NAME" >> "$LOG_FILE"
    dialog --msgbox "Backup created:\n$DEST_DIR/$BACKUP_NAME" 8 60

    create_cron_job
    show_menu
}

create_cron_job() {
    case "$FREQUENCY" in
        daily) CRON_TIME="0 2 * * *" ;;
        weekly) CRON_TIME="0 2 * * 0" ;;
        monthly) CRON_TIME="0 2 1 * *" ;;
        *) CRON_TIME="0 2 * * *" ;;
    esac

    SCRIPT_PATH="/home/vboxuser/backup_automation.sh"

    # Remove existing entry
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "$CRON_TIME bash $SCRIPT_PATH start_backup") | crontab -
    echo "$(date) - Cron job scheduled: $CRON_TIME" >> "$LOG_FILE"
}

# Run the menu
show_menu

