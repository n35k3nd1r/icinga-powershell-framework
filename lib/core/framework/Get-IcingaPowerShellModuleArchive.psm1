<#
.SYNOPSIS
   Download a PowerShell Module from a custom source or from GitHub
   by providing a repository and the user space
.DESCRIPTION
   Download a PowerShell Module from a custom source or from GitHub
   by providing a repository and the user space
.FUNCTIONALITY
   Download and install a PowerShell module from a custom or GitHub source
.EXAMPLE
   PS>Get-IcingaPowerShellModuleArchive -ModuleName 'Plugins' -Repository 'icinga-powershell-plugins' -Stable 1;
.EXAMPLE
   PS>Get-IcingaPowerShellModuleArchive -ModuleName 'Plugins' -Repository 'icinga-powershell-plugins' -Stable 1 -DryRun 1;
.PARAMETER DownloadUrl
   The Url to a ZIP-Archive to download from (skips the wizard)
.PARAMETER ModuleName
   The name which is used inside output messages
.PARAMETER Repository
   The repository to download the ZIP-Archive from
.PARAMETER GitHubUser
   The user from which a repository is downloaded from
.PARAMETER Stable
   Download the latest stable release
.PARAMETER Snapshot
   Download the latest package from the master branch
.PARAMETER DryRun
   Only return the finished build Url including the version to install but
   do not modify the system in any way
.INPUTS
   System.String
.OUTPUTS
   System.Hashtable
.LINK
   https://github.com/Icinga/icinga-powershell-framework
#>

function Get-IcingaPowerShellModuleArchive()
{
    param(
        [string]$DownloadUrl = '',
        [string]$ModuleName  = '',
        [string]$Repository  = ''
    );

    $ProgressPreference = "SilentlyContinue";
    $Tag                = 'master';
    # Fix TLS errors while connecting to GitHub with old PowerShell versions
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";

    if ([string]::IsNullOrEmpty($DownloadUrl)) {
        if ((Get-IcingaAgentInstallerAnswerInput -Prompt ([string]::Format('Do you provide a custom repository for "{0}"?', $ModuleName)) -Default 'n').result -eq 1) {
            $branch = (Get-IcingaAgentInstallerAnswerInput -Prompt 'Which version to you want to install? (snapshot/stable)' -Default 'v' -DefaultInput 'stable').answer
            if ($branch.ToLower() -eq 'snapshot') {
                $DownloadUrl   = [string]::Format('https://github.com/Icinga/{0}/archive/master.zip', $Repository);
            } else {
                $LatestRelease = (Invoke-WebRequest -Uri ([string]::Format('https://github.com/Icinga/{0}/releases/latest', $Repository)) -UseBasicParsing).BaseResponse.ResponseUri.AbsoluteUri;
                $DownloadUrl   = $LatestRelease.Replace('/releases/tag/', '/archive/');
                $Tag           = $DownloadUrl.Split('/')[-1];
                $DownloadUrl   = [string]::Format('{0}/{1}.zip', $DownloadUrl, $Tag);

                $CurrentVersion = Get-IcingaPowerShellModuleVersion $Repository;

                if ($null -ne $CurrentVersion -And $CurrentVersion -eq $Tag) {
                    Write-Host ([string]::Format('Your "{0}" is already up-to-date', $ModuleName));
                    return @{
                        'DownloadUrl' = $DownloadUrl;
                        'Version'     = $Tag;
                        'Directory'   = '';
                        'Archive'     = '';
                        'ModuleRoot'  = (Get-IcingaFrameworkRootPath);
                        'Installed'   = $FALSE;
                    };
                }
            }
        } else {
            $DownloadUrl = (Get-IcingaAgentInstallerAnswerInput -Prompt ([string]::Format('Please enter the full Url to your "{0}" Zip-Archive', $ModuleName)) -Default 'v').answer;
        }
    }

    try {
        $DownloadDirectory   = New-IcingaTemporaryDirectory;
        $DownloadDestination = (Join-Path -Path $DownloadDirectory -ChildPath ([string]::Format('{0}.zip', $Repository)));
        Write-Host ([string]::Format('Downloading "{0}" into "{1}"', $ModuleName, $DownloadDirectory));

        Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $DownloadDestination;
    } catch {
        Write-Host ([string]::Format('Failed to download "{0}" into "{1}". Starting cleanup process', $ModuleName, $DownloadDirectory));
        Start-Sleep -Seconds 2;
        Remove-Item -Path $DownloadDirectory -Recurse -Force;

        Write-Host 'Starting to re-run the download wizard';

        return Get-IcingaPowerShellModuleArchive -ModuleName $ModuleName -Repository $Repository;
    }

    return @{
        'DownloadUrl' = $DownloadUrl;
        'Version'     = $Tag;
        'Directory'   = $DownloadDirectory;
        'Archive'     = $DownloadDestination;
        'ModuleRoot'  = (Get-IcingaFrameworkRootPath);
        'Installed'   = $TRUE;
    };
}
