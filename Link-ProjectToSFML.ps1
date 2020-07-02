# This script links SFML to an existing Visual Studio C++ project.
# How to use :
# 1. Create an "Empty C++ project" in Visual Studio
# 2. Add a new "main.cpp" file
# 3. Run this powershell script and do what is asked.
# Enjoy the time you saved.
#
# I recommend creating a shortcut to this script. This way, you can just double-click the shortcut to run the script.
# Creating a shortcut :
# 1. Create a new shortcut on Windows
# 2. Add the following to the "Target" field in the properties of the shortcut :
# C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File "<PATH_TO_THIS_SCRIPT>\Link-ProjectToSFML.ps1" -NoExit

Add-Type -AssemblyName System.Windows.Forms

function Show-Error($msg)
{
    [System.Windows.Forms.MessageBox]::Show($msg, "Error", "Ok", "Error") | Out-Null
}

function End-Script
{
    Write-Host -NoNewLine 'Press any key to continue...';
    Read-Host | Out-Null
    exit
}

#
# Constants
#
Set-Variable SFML_INCLUDE_DIR -Option Constant -Value ([string]"\include")
Set-Variable SFML_LIB_DIR -Option Constant -Value ([string]"\lib")
Set-Variable SFML_BIN_DIR -Option Constant -Value ([string]"\bin")
Set-Variable SFML_DEBUG_LIBS -Option Constant -Value([string]"sfml-graphics-d.lib; sfml-window-d.lib; sfml-system-d.lib; kernel32.lib;user32.lib;gdi32.lib;winspool.lib;comdlg32.lib;advapi32.lib;shell32.lib;ole32.lib;oleaut32.lib;uuid.lib;odbc32.lib;odbccp32.lib;%(AdditionalDependencies)")
Set-Variable SFML_RELEASE_LIBS -Option Constant -Value([string]"sfml-graphics.lib; sfml-window.lib; sfml-system.lib; kernel32.lib;user32.lib;gdi32.lib;winspool.lib;comdlg32.lib;advapi32.lib;shell32.lib;ole32.lib;oleaut32.lib;uuid.lib;odbc32.lib;odbccp32.lib;%(AdditionalDependencies)")

#
# Choosing a project file
#

Write-Host "Please choose the Visual Studio C++ project (.vcxproj) you want to link to SFML..."



# This is starting folder of the file dialog. Set it to the folder that contains all your projects. 
$DefaultInitialProjectDirectory = "F:\data\projets\projets-personnels"

$ProjectFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$ProjectFileDialog.InitialDirectory = If(Test-Path $DefaultInitialProjectDirectory) { $DefaultInitialProjectDirectory } else { [Environment]::GetFolderPath('Desktop') }
$ProjectFileDialog.Title = "Choose a project file"
$ProjectFileDialog.Multiselect = $false
$ProjectFileDialog.Filter = "VS C++ Project files (*.vcxproj)|*.vcxproj"
$ProjectFileDialog.ShowDialog() | Out-Null

if($ProjectFileDialog.FileName.Length -eq 0 -or -not(Test-Path -Path $ProjectFileDialog.FileName))
{
    Show-Error -msg "Project file not found. Exiting script..."
    End-Script
}

$Project = $ProjectFileDialog.FileName
Write-Host "Project chosen."

#
# Choosing SFML architecture
#

$Arch = Read-Host -Prompt "For what architecture do you want to link SFML ? (32 or 64)"
if($Arch -ne "32" -and $Arch -ne "64")
{
    Show-Error -msg "Stop being a dumbass and choose a valid architecture (32 or 64). Exiting script..."
    End-Script
}

#
# Choosing SFML Directory
#

Write-Host "Select the location of the SFML library on your computer..."
$DefaultInitialSFMLDirectory = "F:\data\libraries"

$SFMLDirDialog = New-Object System.Windows.Forms.FolderBrowserDialog
If(Test-Path $DefaultInitialSFMLDirectory) { $SFMLDirDialog.SelectedPath = $DefaultInitialSFMLDirectory }
$SFMLDirDialog.ShowDialog() | Out-Null

write-host $SFMLDirDialog.SelectedPath

if((-not $SFMLDirDialog.SelectedPath) -or (-not(Test-Path $SFMLDirDialog.SelectedPath)))
{
    Show-Error "Folder not found. Exiting script."
    End-Script
}

$SFMLDir = $SFMLDirDialog.SelectedPath

#
# Linking SFML to the chosen project
#

[xml]$xml = Get-Content -Path $Project
$projectDir = (Get-Item -Path $Project).Directory.FullName

# Uncomment the following line to make a backup of your .vcxproj file before the modifications.
#$xml.Save($projectDir + "\backup-before-sfml-link.vcxproj")

if($xml.Length -eq 0)
{
    Show-Error "The .vcxproj file is empty. Cannot link SFML. Exiting script..."
    End-Script
}

foreach($config in $xml.Project.ItemDefinitionGroup) {
    $ClCompile = $config.ClCompile
    $Link = $config.Link

    if($config.Condition.Contains($Arch))
    {
        # Additional include/library directory

        Write-Host "Adding additional include and library directories for $Arch bit config..."

        $additionalIncludeDirectoriesNode = $xml.CreateNode("element", "AdditionalIncludeDirectories", $ClCompile.NamespaceURI)
        $additionalIncludeDirectoriesNode.InnerText = $SFMLDir + $SFML_INCLUDE_DIR
        $ClCompile.AppendChild($additionalIncludeDirectoriesNode) | Out-Null
        
        $additionalLibraryDirectoriesNode = $xml.CreateNode("element", "AdditionalLibraryDirectories", $Link.NamespaceURI)
        $additionalLibraryDirectoriesNode.InnerText = $SFMLDir + $SFML_LIB_DIR
        $Link.AppendChild($additionalLibraryDirectoriesNode) | Out-Null

        # Dependencies and libs

        $additionalDependencies = $xml.CreateNode("element", "AdditionalDependencies", $Link.NamespaceURI)
        if($config.Condition.Contains("Debug"))
        {
            Write-Host "Linking libs for config Debug|$Arch..."
            $additionalDependencies.InnerText = $SFML_DEBUG_LIBS
        }
        elseif($config.Condition.Contains("Release")) 
        {
            Write-Host "Linking libs for config Release|$Arch..."
            $additionalDependencies.InnerText = $SFML_RELEASE_LIBS
        }
        $Link.AppendChild($additionalDependencies) | Out-Null
    }
}

# Copying DLLs
Write-Host "Copying DLLs into the project directory..."
Copy-Item -Path ($SFMLDir + $SFML_BIN_DIR + '\*') -Destination $projectDir -Force
Write-Host "Dlls copied."
Write-Host "Saving project file..."
$xml.Save($Project)
Write-Host "Saved."

End-Script
