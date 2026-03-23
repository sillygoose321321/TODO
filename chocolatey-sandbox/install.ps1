Choco-install.ps1

# Set directory for installation - Chocolatey does not lock 
# down the directory if not the default
$InstallDir = "$env:LOCALAPPDATA\Programs\Chocolatey"

# Set-ExecutionPolicy Bypass -Scope Process

# All install options - offline, proxy, etc at

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex

choco install puppet-agent.portable -y
choco install ruby.portable -y
choco install git.commandline -y

# pick an editor
#choco install visualstudiocode.portable -y # not yet available
choco install notepadplusplus.commandline -y
#choco install nano -y
#choco install vim-tux.portable

# What else can I install without admin rights?
# https://chocolatey.org/packages?q=id%3Aportable
