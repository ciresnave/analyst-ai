# Ensure script runs with admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator!"
    exit
}

# Install Chocolatey (package manager for Windows)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install dependencies
choco install -y git rust msys2

# Ensure MSYS2 is in the PATH
$env:Path += ";C:\tools\msys64\usr\bin"

# Install cmake and mingw-w64-x86_64-make using MSYS2
& "C:\tools\msys64\msys2.exe" -c "pacman -Sy --noconfirm base-devel mingw-w64-x86_64-toolchain"
& "C:\tools\msys64\msys2.exe" -c "pacman -S --noconfirm mingw-w64-x86_64-cmake"

# Clone llama.cpp for local AI inference
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Convert the current directory to MSYS2 format
$msys2Path = "/c" + (Get-Location).Path.Replace("\", "/").Substring(2)

# Build llama.cpp with CMake
& "C:\tools\msys64\msys2.exe" -c "cd $msys2Path && mkdir -p build && cd build && cmake .. && cmake --build ."

# Download a model (e.g., 7B parameter GGUF format) - adjust URL as needed
# Note: You’ll need to source a GGUF model file from Hugging Face or similar (e.g., TheBloke’s quantized models)
$modelUrls = "https://huggingface.co/unsloth/DeepSeek-R1-GGUF/resolve/main/DeepSeek-R1-UD-IQ1_S/DeepSeek-R1-UD-IQ1_S-00001-of-00003.gguf", "https://huggingface.co/unsloth/DeepSeek-R1-GGUF/resolve/main/DeepSeek-R1-UD-IQ1_S/DeepSeek-R1-UD-IQ1_S-00002-of-00003.gguf", "https://huggingface.co/unsloth/DeepSeek-R1-GGUF/resolve/main/DeepSeek-R1-UD-IQ1_S/DeepSeek-R1-UD-IQ1_S-00003-of-00003.gguf"
foreach ($modelUrl in $modelUrls) {
    Invoke-WebRequest -Uri $modelUrl -OutFile "models/$(Split-Path $modelUrl -Leaf)"
    if (Test-Path "models/$(Split-Path $modelUrl -Leaf)") {
        Write-Host "Model part downloaded successfully: $(Split-Path $modelUrl -Leaf)"
    }
    else {
        Write-Host "Model part download failed: $(Split-Path $modelUrl -Leaf)"
    }
}

# Return to root directory
cd ..

prompt "Would you like to run the server now? (y/n)" runServer
if ($runServer -eq "y") {
    cargo run --release
}
else {
    Write-Host "You can run the server later with 'cargo run'."
}