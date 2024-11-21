#!/bin/bash

clear
BINARY_NAME="fizz"
VERSION="latest"
FIZZUP_VERSION="v1.1.1"

# Fizz variables
GATEWAY_ADDRESS="provider.vycod.com" # Provider domain: example = provider.devnetcsphn.com
GATEWAY_PROXY_PORT="8553" # Proxyport = 8553
GATEWAY_WEBSOCKET_PORT="8544" # ws url of the gateway example= ws://provider.devnetcsphn.com:8544
CPU_PRICE="6"
CPU_UNITS="8"
MEMORY_PRICE="2.4000000000000004"
MEMORY_UNITS="24"
STORAGE_PRICE="10"
WALLET_ADDRESS="0xCEd44a91f993649eB9E63Fe09d80A9C82C7b446b" 
USER_TOKEN="0x382ad474b8d9b180307b8000352b723a8baf7e5c8237a3e5e59cee63739cd1fe3b80ff3cef8602146d7b5ef35d6b1e06568c42bd0d6803845d938ff3f262f20101"
STORAGE_UNITS="1000"
GPU_MODEL=""
GPU_UNITS="0"
GPU_PRICE="0"
GPU_MEMORY="0"
GPU_ID=""
OS_ID="linux"

# Function to detect the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     
            if grep -q Microsoft /proc/version; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

OS=$(detect_os)

# Add OS verification check
if [ "$OS" != "$OS_ID" ]; then
    echo "Error: OS mismatch. Your system is running '$OS' but OS_ID is set to '$OS_ID'"
    exit 1
fi

ARCH="$(uname -m)"
# Function to display system information
display_system_info() {
    echo "System Information:"
    echo "==================="
    echo "Detecting system configuration..."
    echo "Operating System: $OS"
    echo "Architecture: $ARCH"
    # CPU information
    case $OS in
        macos)
            cpu_cores=$(sysctl -n hw.ncpu)
            ;;
        linux|wsl)
            cpu_cores=$(nproc)
            ;;
        *)
            cpu_cores="Unknown"
            ;;
    esac
    echo "Available CPU cores: $cpu_cores"
    
    # disable cpu check
    # if [ "$cpu_cores" != "$CPU_UNITS" ]; then
    # echo "Error: Available CPU cores ($cpu_cores) does not match CPU_UNITS ($CPU_UNITS)"
    # exit 1
    # fi
    
    # Memory information
    case $OS in
        macos)
            total_memory=$(sysctl -n hw.memsize | awk '{printf "%.2f GB", $1 / 1024 / 1024 / 1024}')
            available_memory=$(vm_stat | awk '/Pages free/ {free=$3} /Pages inactive/ {inactive=$3} END {printf "%.2f GB", (free+inactive)*4096/1024/1024/1024}')
            ;;
        linux|wsl)
            total_memory=$(free -h | awk '/^Mem:/ {print $2}')
            available_memory=$(free -h | awk '/^Mem:/ {print $7}')
            ;;
        *)
            total_memory="Unknown"
            available_memory="Unknown"
            ;;
    esac
    echo "Total memory: $total_memory"
    echo "Available memory: $available_memory"
    
     if command -v nvidia-smi &> /dev/null; then
        echo -e "\nNVIDIA GPU Information:"
        echo "========================"
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    fi
    
}

# Function to check bandwidth
check_bandwidth() {
    echo "Checking bandwidth..."
    if ! command -v speedtest-cli &> /dev/null; then
        echo "speedtest-cli not found. Installing..."
        case $OS in
            macos)
                brew install speedtest-cli
                ;;
            linux|wsl)
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y speedtest-cli
                elif command -v yum &> /dev/null; then
                    sudo yum install -y speedtest-cli
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y speedtest-cli
                else
                    echo "Unable to install speedtest-cli. Please install it manually."
                    return 1
                fi
                ;;
            *)
                echo "Unsupported OS for automatic speedtest-cli installation. Please install it manually."
                return 1
                ;;
        esac
    fi

    # Run speedtest and capture results
    result=$(speedtest-cli 2>&1)
    if echo "$result" | grep -q "ERROR"; then
        echo "Error running speedtest: $result"
        BANDWIDTH_RANGE="NA"
    else
        download=$(echo "$result" | grep "Download" | awk '{print $2}')
        upload=$(echo "$result" | grep "Upload" | awk '{print $2}')

        if [[ -z "$download" || -z "$upload" ]]; then
            echo "Error: Could not parse download or upload speed"
            BANDWIDTH_RANGE="NA"
        else
            echo "Download speed: $download Mbit/s"
            echo "Upload speed: $upload Mbit/s"

            # Determine bandwidth range
            total_speed=$(echo "$download + $upload" | bc 2>/dev/null)
            if [[ $? -ne 0 || -z "$total_speed" ]]; then
                echo "Error: Could not calculate total speed"
                BANDWIDTH_RANGE="NA"
            else
                if (( $(echo "$total_speed < 50" | bc -l) )); then
                    BANDWIDTH_RANGE="10mbps"
                elif (( $(echo "$total_speed < 100" | bc -l) )); then
                    BANDWIDTH_RANGE="50mbps"
                elif (( $(echo "$total_speed < 200" | bc -l) )); then
                    BANDWIDTH_RANGE="100mbps"
                elif (( $(echo "$total_speed < 300" | bc -l) )); then
                    BANDWIDTH_RANGE="200mbps"
                elif (( $(echo "$total_speed < 400" | bc -l) )); then
                    BANDWIDTH_RANGE="300mbps"
                elif (( $(echo "$total_speed < 500" | bc -l) )); then
                    BANDWIDTH_RANGE="400mbps"
                elif (( $(echo "$total_speed < 1000" | bc -l) )); then
                    BANDWIDTH_RANGE="500mbps"
                elif (( $(echo "$total_speed < 5000" | bc -l) )); then
                    BANDWIDTH_RANGE="1gbps"
                elif (( $(echo "$total_speed < 10000" | bc -l) )); then
                    BANDWIDTH_RANGE="5gbps"
                elif (( $(echo "$total_speed >= 10000" | bc -l) )); then
                    BANDWIDTH_RANGE="10gbps"
                else
                    BANDWIDTH_RANGE="NA"
                fi
            fi
        fi
    fi

    echo "Bandwidth range: $BANDWIDTH_RANGE"
}

echo "========================================================================================================================"
echo ""
echo "                   â–„â–„                                                          â–„â–„                                       "
echo " â–„â–ˆâ–€â–€â–€â–ˆâ–„â–ˆ         â–ˆâ–ˆâ–ˆ                                               â–€â–ˆâ–ˆâ–ˆâ–€â–€â–€â–ˆâ–ˆâ–ˆ â–ˆâ–ˆ                                       "
echo "â–„â–ˆâ–ˆ    â–€â–ˆ          â–ˆâ–ˆ                                                 â–ˆâ–ˆ    â–€â–ˆ                                          "
echo "â–€â–ˆâ–ˆâ–ˆâ–„   â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–„ â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–„   â–„â–„â–ˆâ–€â–ˆâ–ˆâ–€â–ˆâ–ˆâ–ˆâ–„â–ˆâ–ˆâ–ˆ  â–„â–ˆâ–ˆâ–€â–ˆâ–ˆâ–„â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–„       â–ˆâ–ˆ   â–ˆ â–€â–ˆâ–ˆâ–ˆ  â–ˆâ–€â–€â–€â–ˆâ–ˆâ–ˆ â–ˆâ–€â–€â–€â–ˆâ–ˆâ–ˆâ–€â–ˆâ–ˆâ–ˆ  â–€â–ˆâ–ˆâ–ˆ â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–„ "
echo "  â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–„ â–ˆâ–ˆ   â–€â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ  â–„â–ˆâ–€   â–ˆâ–ˆ â–ˆâ–ˆâ–€ â–€â–€ â–ˆâ–ˆâ–€   â–€â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ       â–ˆâ–ˆâ–€â–€â–ˆâ–ˆ   â–ˆâ–ˆ  â–€  â–ˆâ–ˆâ–ˆ  â–€  â–ˆâ–ˆâ–ˆ   â–ˆâ–ˆ    â–ˆâ–ˆ   â–ˆâ–ˆ   â–€â–ˆâ–ˆ "
echo "â–„     â–€â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ  â–ˆâ–ˆâ–€â–€â–€â–€â–€â–€ â–ˆâ–ˆ     â–ˆâ–ˆ     â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ       â–ˆâ–ˆ   â–ˆ   â–ˆâ–ˆ    â–ˆâ–ˆâ–ˆ     â–ˆâ–ˆâ–ˆ    â–ˆâ–ˆ    â–ˆâ–ˆ   â–ˆâ–ˆ    â–ˆâ–ˆ "
echo "â–ˆâ–ˆ     â–ˆâ–ˆ â–ˆâ–ˆ   â–„â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ  â–ˆâ–ˆâ–„    â–„ â–ˆâ–ˆ     â–ˆâ–ˆâ–„   â–„â–ˆâ–ˆ â–ˆâ–ˆ    â–ˆâ–ˆ       â–ˆâ–ˆ       â–ˆâ–ˆ   â–ˆâ–ˆâ–ˆ  â–„  â–ˆâ–ˆâ–ˆ  â–„  â–ˆâ–ˆ    â–ˆâ–ˆ   â–ˆâ–ˆ   â–„â–ˆâ–ˆ "
echo "â–ˆâ–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–€  â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–€ â–ˆâ–ˆâ–ˆâ–ˆ  â–ˆâ–ˆâ–ˆâ–ˆâ–„ â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–€â–ˆâ–ˆâ–ˆâ–ˆâ–„    â–€â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–€â–„â–ˆâ–ˆâ–ˆâ–ˆ  â–ˆâ–ˆâ–ˆâ–ˆâ–„   â–„â–ˆâ–ˆâ–ˆâ–ˆâ–„   â–„â–ˆâ–ˆâ–ˆâ–ˆâ–„â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆ â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆ  â–€â–ˆâ–ˆâ–ˆâ–ˆâ–€â–ˆâ–ˆâ–ˆâ–„ â–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–ˆâ–€  "
echo "          â–ˆâ–ˆ                                                                                                   â–ˆâ–ˆ       "
echo "        â–„â–ˆâ–ˆâ–ˆâ–ˆâ–„                                                                                               â–„â–ˆâ–ˆâ–ˆâ–ˆâ–„     "
echo ""
echo "                                                                                             - Making edge AI possible. "
echo "========================================================================================================================"
echo ""
echo "$BINARY_NAME Version: $VERSION"
echo ""

# Detect if an Nvidia GPU is present (only for Linux or WSL)
if [ "$OS" = "linux" ] || [ "$OS" = "wsl" ]; then
    NVIDIA_PRESENT=$(if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then echo "true"; elif lspci | grep -i nvidia >/dev/null 2>&1; then echo "true"; else echo ""; fi)
else
    NVIDIA_PRESENT=""
fi

test_gpu_container() {
    if [ -z "$NVIDIA_PRESENT" ]; then
        return
    fi

    echo "Testing GPU container creation..."
    
    # Try to run a simple NVIDIA GPU test container
    if ! docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi; then
        echo "ERROR: Failed to create GPU container. Please check your NVIDIA driver and Docker installation."
        echo "Make sure nvidia-docker2 is installed and Docker service is configured to use the NVIDIA runtime."
        echo "You may need to restart Docker service after installing nvidia-docker2."
        exit 1
    fi
    
    echo "GPU container test successful!"
}

# Check for 'info' flag
if [ "$1" == "info" ]; then
    display_system_info
    check_bandwidth
    exit 0
elif [ "$1" == "test-gpu" ]; then
    test_gpu_container
    exit 0
fi



display_system_info 
check_bandwidth

check_install_nvidia_toolkit() {
    if [ "$OS" = "macos" ]; then
        return
    fi
    if ! command -v nvidia-container-toolkit &> /dev/null; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y nvidia-cuda-toolkit
        elif command -v yum &> /dev/null; then
            sudo yum install -y nvidia-cuda-toolkit
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y nvidia-cuda-toolkit
        else
            echo "Unable to install NVIDIA Container Toolkit. Please install it manually."
            return 1
        fi
        echo "NVIDIA Container Toolkit installed successfully."
    fi
}


# Install NVIDIA Driver, Container Toolkit 
install_gpu_dependencies() {
    check_install_nvidia_toolkit
    case $OS in
        linux)
            if [ -n "$NVIDIA_PRESENT" ]; then
                echo "NVIDIA GPU detected. Checking driver installation..."
                if ! nvidia-smi &>/dev/null; then
                    echo "NVIDIA driver not found. Installing..."
                    
                    # Detect the Linux distribution
                    if [ -f /etc/os-release ]; then
                        . /etc/os-release
                        case $ID in
                            ubuntu|debian)
                                sudo apt update
                                sudo apt install -y alsa-utils
                                sudo ubuntu-drivers autoinstall
                                sudo apt install -y linux-headers-$(uname -r)
                                sudo apt install -y nvidia-driver-latest-dkms
                                ;;
                            fedora)
                                sudo dnf update -y
                                sudo dnf install -y akmod-nvidia
                                sudo dnf install -y xorg-x11-drv-nvidia-cuda
                                ;;
                            centos|rhel)
                                sudo yum update -y
                                sudo yum install -y epel-release
                                sudo yum install -y kmod-nvidia
                                ;;
                            opensuse*|sles)
                                sudo zypper refresh
                                sudo zypper install -y nvidia-driver
                                ;;
                            *)
                                echo "Unsupported Linux distribution for automatic NVIDIA driver installation."
                                echo "Please install the NVIDIA driver manually for your distribution."
                                return 1
                                ;;
                        esac
                        echo "NVIDIA driver installed. A system reboot is required."
                        echo "Rebooting your system and please run the script again."
                        sudo reboot
                        exit 0
                    else
                        echo "Unable to determine Linux distribution. Please install NVIDIA driver manually."
                        return 1
                    fi
                else
                    echo "NVIDIA driver is already installed."
                fi
            else
                echo "No NVIDIA GPU detected. Skipping driver installation."
            fi
            ;;
        macos|wsl)
            echo "NVIDIA driver installation is not applicable for macOS or WSL."
            ;;
        *)
            echo "Unsupported operating system for NVIDIA driver installation."
            ;;
    esac
}

# Install NVIDIA Driver, Container Toolkit 
install_gpu_dependencies

# Check and update CUDA
check_and_update_cuda() {
    if [ "$OS" = "macos" ]; then
        return
    fi

    if [ -z "$NVIDIA_PRESENT" ]; then
        echo "No NVIDIA GPU detected. Skipping cuda check."
        return
    fi

    local min_version="11.8"
    local cuda_version=""

    # Check if CUDA is installed
    if command -v nvcc &> /dev/null; then
        cuda_version=$(nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        echo "Current CUDA version: $cuda_version"
    elif [ -x "/usr/local/cuda/bin/nvcc" ]; then
        cuda_version=$(/usr/local/cuda/bin/nvcc --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        echo "Current CUDA version: $cuda_version"
    elif [ -x "/usr/bin/nvidia-smi" ]; then
        cuda_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
        echo "Current CUDA version (based on NVIDIA driver): $cuda_version"
    else
        echo "CUDA is not installed or not found in the expected locations."
    fi
    export CUDA_VERSION=$cuda_version
    export NVIDIA_DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
    # Installation process (unchanged)
    case $OS in
        linux)
            # Detect distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                case $ID in
                    ubuntu|debian)
                        wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
                        sudo dpkg -i cuda-keyring_1.0-1_all.deb
                        sudo apt-get update
                        sudo apt-get -y install cuda
                        ;;
                    fedora|centos|rhel)
                        sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/fedora37/x86_64/cuda-fedora37.repo
                        sudo dnf clean all
                        sudo dnf -y module install nvidia-driver:latest-dkms
                        sudo dnf -y install cuda
                        ;;
                    *)
                        echo "Unsupported distribution for automatic CUDA installation. Please install CUDA manually."
                        return 1
                        ;;
                esac

                # Update PATH and LD_LIBRARY_PATH
                echo 'export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}' >> ~/.bashrc
                echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> ~/.bashrc
                source ~/.bashrc

                echo "Latest CUDA has been installed. Please reboot your system."
                echo "After reboot, run 'nvcc --version' to verify the installation."
            else
                echo "Unable to determine Linux distribution. Please install CUDA manually."
                return 1
            fi
            ;;
        wsl)
            echo "Error: CUDA installation is not supported on WSL. Please install CUDA manually."
            exit 1
            ;;
        *)
            echo "Error: CUDA installation is only supported on Linux."
            exit 1
            ;;
    esac
}

check_and_update_cuda

# Check and install Docker, Docker Compose
install_docker_and_compose() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Installing Docker..."
        
        case $OS in
            macos)
                if ! command -v brew &> /dev/null; then
                    echo "Homebrew is not installed. Installing Homebrew..."
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    
                    # Add Homebrew to PATH
                    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                    
                    if ! command -v brew &> /dev/null; then
                        echo "Failed to install Homebrew. Please install it manually and run the script again."
                        exit 1
                    fi
                    echo "Homebrew installed successfully."
                fi
                brew install --cask docker
                echo "Docker for macOS has been installed. Please start Docker from your Applications folder."
                ;;
            
            linux)
                if [ -f /etc/os-release ]; then
                    . /etc/os-release
                    case $ID in
                        ubuntu|debian)
                            sudo apt-get update
                            sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
                            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
                            sudo apt-get update
                            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        fedora)
                            sudo dnf -y install dnf-plugins-core
                            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                            sudo dnf install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        centos|rhel)
                            sudo yum install -y yum-utils
                            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                            sudo yum install -y docker-ce docker-ce-cli containerd.io
                            ;;
                        *)
                            echo "Unsupported Linux distribution for automatic Docker installation."
                            echo "Please install Docker manually for your distribution."
                            exit 1
                            ;;
                    esac
                    
                    # Start and enable Docker service
                    
