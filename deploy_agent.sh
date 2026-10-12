#!/bin/bash


the_backup_status_error() {
    echo ""
    echo "!!! An error occured in the process setup !!!"
    
   
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
        echo "Saving in the  zip file..."
        zip -r "${PROJECT_DIR}_archive.zip" "$PROJECT_DIR" > /dev/null 2>&1
        
        echo "Directory cleanup..."
        rm -rf "$PROJECT_DIR"
        
        echo "Half setpup was saves as : ${PROJECT_DIR}_archive.zip"
    fi
    echo "Program exit successful!"
    exit 1
}


deployment_start() {
 
    # FIXED ERROR HERE: Points to your correct function name
    trap the_backup_status_error SIGINT SIGTSTP

    echo "--- The deployment has started ---"

  
    python3 --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: message python not installed!"
        exit 1
    fi

    which zip > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Missing zip program."
        exit 1
    fi
    echo "Congrats python and zip were successfully installed!"


    echo "Write a  name for  your project folder (attendance_tracker_...):"
    read chosen_suffix

    if [ -z "$chosen_suffix" ]; then
        echo "Nothing was wrote!."
        exit 1
    fi

    
    PROJECT_DIR="attendance_tracker_${chosen_suffix}"

    # Check if that folder name is already taken
    if [ -d "$PROJECT_DIR" ]; then
        echo "Folder with the name $PROJECT_DIR is already created! Do you want to restart? (y/n)"
        read overwrite_choice
        if [ "$overwrite_choice" != "y" ] && [ "$overwrite_choice" != "Y" ]; then
            echo "Deployment stopping."
            exit 1
        fi
        echo "Clearing the older folder now..."
        rm -rf "$PROJECT_DIR"
    fi

    
    echo "Setting the folder direction..."
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/Helpers"
    mkdir -p "$PROJECT_DIR/reports"
    mkdir -p "$PROJECT_DIR/archives/attendance"
    mkdir -p "$PROJECT_DIR/archives/absent"

    
    cp "templates/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py"
    cp "templates/config.json" "$PROJECT_DIR/Helpers/config.json"

    
    echo "[Test] Running a simulation for 4 seconds... you can press Ctrl+C to test the backup trap!"
    sleep 4

    
    echo "How would you like to proceed with the student roster?"
    echo "  1) Transfer the rows from the template roster file"
    echo "  2) Create a new roster"
    read roster_choice

    if [ "$roster_choice" = "1" ]; then
        echo "What is the number of students you want to copy over? (Choose  from 1 to 10)"
        read student_count
        
        
        if ! [[ "$student_count" =~ ^[1-9]$|^10$ ]]; then
            student_count=10
        fi
        
        
        head -n 1 "templates/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv"
        tail -n +2 "templates/assets.csv" | head -n "$student_count" >> "$PROJECT_DIR/Helpers/assets.csv"
        
        
        sed -i 's/"total_sessions":.*/"total_sessions": 5/g' "$PROJECT_DIR/Helpers/config.json"
        echo "The copie was a success! Set total_sessions to 5 in config."

    else
        
        echo "Email,Names,Attendance Count,Absence Count" > "$PROJECT_DIR/Helpers/assets.csv"
        echo "samA@example.com,SamA,0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        echo "samB@example.com,SamB,0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        echo "samC@example.com,SamC,0,0" >> "$PROJECT_DIR/Helpers/assets.csv"
        
      
        sed -i 's/"total_sessions":.*/"total_sessions": 1/g' "$PROJECT_DIR/Helpers/config.json"
        echo "The new roster was created! Begin total_sessions to 1 in config."
    fi

    # Set file access permissions
    chmod +x "$PROJECT_DIR/attendance_checker.py"
    chmod 600 "$PROJECT_DIR/Helpers/config.json"
    echo "The script is now executable and config.json is now finalised to owner read/write."

    # Prompt user to adjust alert threshold metrics
    echo "Would you like to edit the attendance alert  in config.json? (y/n)"
    read threshold_choice
    if [ "$threshold_choice" = "y" ] || [ "$threshold_choice" = "Y" ]; then
        echo "Write the new warning percent value (the default is 75):"
        read user_warn
        echo "Write  the new failure percent value (the default is 50):"
        read user_fail

        
        user_warn=${user_warn:-75}
        user_fail=${user_fail:-50}

        sed -i "s/\"warning\": 75/\"warning\": $user_warn/g" "$PROJECT_DIR/Helpers/config.json"
        sed -i "s/\"failure\": 50/\"failure\": $user_fail/g" "$PROJECT_DIR/Helpers/config.json"
        echo "The threshold were updated successfully!"
    fi

    echo ""
    echo "The setup was successful the verification is starting..."
    echo ""
    
    
    trap - SIGINT SIGTSTP
    
    start_the_application "$chosen_suffix"
}


start_the_application() {
    local target_suffix="$1"
    
    # If no suffix was passed from step 1, ask the user interactively
    if [ -z "$target_suffix" ]; then
        echo "--- Executing!"
        echo "Write the suffix name of your deployment:"
        read target_suffix
    fi

    local run_directory="attendance_tracker_${target_suffix}"

    if [ ! -d "$run_directory" ]; then
        echo "Error: Folder name not found'$run_directory'. it needs to be deployed first!"
        return 1
    fi

    echo "Running Python tracking . Follow the  prompts to grade the students..."
    
    (cd "$run_directory" && python3 attendance_checker.py)
    
    echo "The session ended succesfully."
}


save_and_archive_logs() {
    echo "--- Archiving Run Logs ---"
    echo "Write the suffix name of the project folder r:"
    read target_suffix

    local run_directory="attendance_tracker_${target_suffix}"

    if [ ! -d "$run_directory" ]; then
        echo "Error: Folder not found! '$run_directory'."
        return 1
    fi


    local current_time=$(date +"%Y%m%d_%H%M%S")
    local saved_anything=false

  
    if [ -f "$run_directory/reports/attendance.log" ]; then
        cp "$run_directory/reports/attendance.log" "$run_directory/archives/attendance/attendance_${current_time}.log"
        echo "  Attendance archized successfully/attendance/ directory!"
        saved_anything=true
    else
        echo "Note: The attendance.log was not found ."
    fi

    if [ -f "$run_directory/reports/absent.log" ]; then
        cp "$run_directory/reports/absent.log" "$run_directory/archives/absent/absent_${current_time}.log"
        echo "The absence was archized successfully/absent/ directory!"
        saved_anything=true
    else
        echo "Notice: The absent.log was not found ."
    fi

    if [ "$saved_anything" = false ]; then
        echo "Log files not found in the folder , the app needs to be run first!"
    fi
}


while true; do
    echo ""
    echo "=========================================="
    echo "       The ATTENDANCE managimg member         "
    echo "=========================================="
    echo " 1) Launch the new project "
    echo " 2) Execute the existing project "
    echo " 3) Archive generated session logs"
    echo " 4) Close the program"
    echo "=========================================="
    echo "Pick from (1-4):"
    read menu_pick
    echo ""

    if [ "$menu_pick" = "1" ]; then
        # FIXED ERROR HERE: Calls your correct deployment function name
        deployment_start
    elif [ "$menu_pick" = "2" ]; then
        start_the_application ""
    elif [ "$menu_pick" = "3" ]; then
        save_and_archive_logs
    elif [ "$menu_pick" = "4" ]; then
        echo "I am exiting the program!"
        exit 0
    else
        # FIXED ERROR HERE: Closed the cut-off loop code cleanly
        echo "Invalid selection. Please choose 1, 2, 3, or 4."
    fi
done
