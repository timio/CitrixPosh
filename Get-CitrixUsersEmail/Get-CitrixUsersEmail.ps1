# Author: timio
# Filename: Get-CitrixUsersEmail.ps1
# Last Modified Date: 6/19/2017

<#

.SYNOPSIS
    Retrieve email addresses of corp users from Citrix environment
.DESCRIPTION
    Gets email addresses of users that belong to a specific delivery group in Citrix or AD Security group.  If there is no group specified, it will return all users in Citrix environment.  Required Parameters are -DeliveryController and -FileLocation.

.PARAMETER DeliveryGroup
    Published name of Citrix delivery group
.PARAMETER DeliveryController
    Delivery controller address
.PARAMETER FileLocation
    Path and filename of csv file
.PARAMETER ADGroup
    AD security group name

.EXAMPLE
    Get-CitrixUsersEmail -DeliveryController controller.local -FileLocation "C:\report\userlist.csv"
    
    Will output all Citrix user email addresses to file location specified.  

.EXAMPLE
    Get-CitrixUsersEmail -DeliveryController controller.local -FileLocation "C:\report\userlist.csv" -DeliveryGroup "Windows 10"
    
    Will output Citrix user email addresses to file location specified that belong to the Delivery Group with published name "Windows 10".

.EXAMPLE
    Get-CitrixUsersEmail -DeliveryController controller.local -FileLocation "C:\report\userlist.csv" -ADGroup "Domain Admins"
    
    Will output Citrix user email addresses to file location specified that belong to the AD Group "Domain Admins".

#>

function Get-CitrixUsersEmail
{
    [CmdletBinding()]
    Param
    (
        # Desktop Group Param -DeliveryGroup
        [Parameter(
            Mandatory=$false,
            HelpMessage='Enter Desktop group name found in Studio')]
        [string]$DeliveryGroup,

        # File Group Param -FileLocation
        [Parameter(
            Mandatory=$true,
            HelpMessage='File output location')]
        [string]$FileLocation,
        
        # Citrix Delivery Controller Admin Address -DeliveryController
        [Parameter(
            Mandatory=$true,
            HelpMessage='Citrix delivery controller address')]
        [string]$DeliveryController,
        
        # Search by AD Group -ADGroup
        [Parameter(
            Mandatory=$false,
            HelpMessage='Citrix delivery controller address')]
        [string]$ADGroup
    )

    Begin
    {

        #Check for multiple params

        if($DeliveryGroup -and $ADGroup){
        
            Write-Host "ERROR - Cannot use DeliveryGroup and ADGroup parameters together. Please specify one." -ForegroundColor Red
            break
        
        }

    }

    Process
    {

        #Check for installed modules and snapins

        ### Active Directory
        Write-Host "Trying Import of Active Directory Module..."

        if(!(Get-Module -Name ActiveDirectory)){
            
            Import-Module ActiveDirectory -ErrorAction SilentlyContinue
            Write-Host "Active Directory Imported Successfully." -ForegroundColor Green
            
        } elseif( Get-Module -Name ActiveDirectory ){
        
            Write-Host "Active Directory Module is installed." -ForegroundColor Green
        
        } else{
            
            Write-Host "ERROR - Ending Script." -ForegroundColor Red
            Write-Host "Active Directory module cannot be found." -ForegroundColor Red
            Write-Host "Review Microsoft Article - https://blogs.msdn.microsoft.com/rkramesh/2012/01/17/how-to-add-active-directory-module-in-powershell-in-windows-7/" -ForegroundColor Red
            Break
        }

        ### Citrix SnapIn
        
        Write-Host "Trying Adding Citrix PowerShell SnapIns..."

        if(!(Get-PSSnapin -Name Citrix* -ErrorAction SilentlyContinue)){
            
            Add-PSSnapin -Name Citrix*
            Write-Host "Citrix SnapIn Imported Successfully." -ForegroundColor Green
            
         } elseif( Get-PSSnapin -Name Citrix* ){
         
            Write-Host "Citrix SnapIns are installed." -ForegroundColor Green
         
         } else{
            
            Write-Host "ERROR - Ending Script." -ForegroundColor Red
            Write-Host "Citrix SnapIns cannot be found." -ForegroundColor Red
            Write-Host "Citrix Article - https://docs.citrix.com/en-us/citrix-cloud/xenapp-and-xendesktop-service/remote-powershell-sdk.html" -ForegroundColor Red
            Break
            
         }

        #If any parameters selected search by that criteria, else return all active user email addresses

        if($DeliveryGroup){
        
            if(Get-BrokerDesktopGroup -AdminAddress $DeliveryController -PublishedName $DeliveryGroup ){
            
                $desktopGroupUID = Get-BrokerDesktopGroup -AdminAddress $DeliveryController -PublishedName $DeliveryGroup | select Uid -ExpandProperty Uid
                Get-BrokerDesktop -AdminAddress $DeliveryController -DesktopGroupUid $desktopGroupUID -Property AssociatedUserUPNs -MaxRecordCount 9999 | where {$_.AssociatedUserUPNs -ne $null} | Select @{Label="Email Address";Expression={$_.AssociatedUserUPNs}} | Export-Csv $FileLocation -Force -NoTypeInformation
                Write-Host "File Successfully Created - $FileLocation" -ForegroundColor Green
            
            } else{
                
                $validNames = Get-BrokerDesktopGroup -Property PublishedName
                Write-Host "ERROR - Delivery Group entered cannot be found." -ForegroundColor Red
                Write-Host "Valid names include the following:" -ForegroundColor Red
                foreach($item in $validNames){
                
                    Write-Host $item.PublishedName -ForegroundColor Yellow

                }
                Break
            
            }
        
        } elseif($ADGroup) { 
        
            if(Get-ADGroupMember -Identity $ADGroup){
            
                $members = Get-ADGroupMember -Identity $ADGroup | select SID
                $arr = @()
                foreach($member in $members){
                    
                    $sid = $member.SID
                    $brokerUser = Get-BrokerUser -AdminAddress $DeliveryController -SID $sid -ErrorAction SilentlyContinue | where {$_.UPN -ne $null} | Select @{Label="Email Address";Expression={$_.UPN}}
                    $arr += $brokerUser
                }
                
                $arr | Export-Csv $FileLocation -Force -NoTypeInformation
                Write-Host "File Successfully Created - $FileLocation" -ForegroundColor Green
            
            } else{
                
                Write-Host "ERROR - Cannot find $ADGroup in Active Directory environment." -ForegroundColor Red
                break
            
            }
        
        } else {
        
            Get-BrokerUser -AdminAddress $DeliveryController -Property UPN -MaxRecordCount 9999 | where {$_.UPN -ne $null} | Select @{Label="Email Address";Expression={$_.UPN}} | Export-Csv $FileLocation -Force -NoTypeInformation
            Write-Host "File Successfully Created - $FileLocation" -ForegroundColor Green

        }

    }

    End
    {
    }
}