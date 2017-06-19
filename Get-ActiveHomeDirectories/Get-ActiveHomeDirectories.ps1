# Author: timio
# Filename: Get-ActiveHomeDirectories.ps1
# Last Modified Date: 6/19/2017

<#

.SYNOPSIS
    Retrieve user info and home directory of active/assigned Citrix Desktop Users.
.DESCRIPTION
    Checks for AD module and Citrix Snapin.  Retrieves user info (first name, last name, sam, upn, employeeID, home directory, and citrix machine) if user has active machine.
.PARAMETER ADGroup
    Name of AD Security Group(s)
.PARAMETER DeliveryController
    Citrix Delivery controller address
.PARAMETER FileLocation
    Path and filename of csv file
.EXAMPLE
    Get-ActiveHomeDirectories -ADGroup "Group 1","Group 2","Group 3","Group 4" -DeliverController admincontrolleraddress.local -FileLocation C:\Desktop\file.txt

    Produces file specified in FileLocation parameter for all matched users.
#>

function Get-ActiveHomeDirectories
{
    [CmdletBinding()]
    Param
    (
        # Search by AD Group -ADGroup
        [Parameter(
            Mandatory=$true,
            HelpMessage='AD Group Name')]
        [array]$ADGroup,
        
        # Citrix Delivery Controller Admin Address -DeliveryController
        [Parameter(
            Mandatory=$true,
            HelpMessage='Citrix delivery controller address')]
        [string]$DeliveryController,

        # File Group Param -FileLocation
        [Parameter(
            Mandatory=$true,
            HelpMessage='File output location')]
        [ValidatePattern( '.csv' )]
        [string]$FileLocation
    )

    Begin
    {
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

         #Validate AD Groups
         Write-Host "Validating AD Groups..."

         foreach($group in $ADGroup){
         
            if(!(Get-ADGroupMember -Identity $group)){
            
                Write-Host "Active Directory group $group not found!" -ForegroundColor Red
                Break
            
            } else {

                Write-Host "$group is valid." -ForegroundColor Green

            }
         
         }

         #Collection
         $matches = @()

         #Retrieve all sams and store in an array
         $sams = @()
         foreach($item in $ADGroup){
         
            $getSams = Get-ADGroupMember -Identity $item | select SamAccountName
            $sams += $getSams

         }

         #Loop through Groups and store SAM's in array
         ## Get Domain prefix
         $netBiosName = Get-ADDomain | select NetBIOSName -ExpandProperty NetBIOSName
         $prefix = "$($netBiosName)" + "\"

         foreach($sam in $sams){

            $match = New-Object System.Object
            $domainUserName = $prefix + $sam.SamAccountName
            if(Get-BrokerMachine -AdminAddress $DeliveryController -AssociatedUserName $domainUserName){
            
                $getADInfo = Get-ADUser -Identity $sam.SamAccountName -Properties *
                $getBrokerInfo = (Get-BrokerMachine -AdminAddress $DeliveryController -AssociatedUserName $domainUserName | select DNSName -ExpandProperty DNSName) -join ","
                $match | Add-Member -MemberType NoteProperty -Name FirstName -Value $getADInfo.GivenName
                $match | Add-Member -MemberType NoteProperty -Name LastName -Value $getADInfo.Surname
                $match | Add-Member -MemberType NoteProperty -Name SAMName -Value $getADInfo.SamAccountName
                $match | Add-Member -MemberType NoteProperty -Name EmployeeID -Value $getADInfo.EmployeeID
                $match | Add-Member -MemberType NoteProperty -Name UPN -Value $getADInfo.UserPrincipalName
                $match | Add-Member -MemberType NoteProperty -Name HomeDirectory -Value $getADInfo.HomeDirectory
                $match | Add-Member -MemberType NoteProperty -Name AssignedMachine -Value $getBrokerInfo
                $matches += $match
            
            }

         }

         $matches | Export-Csv $FileLocation -Force -NoTypeInformation
        
    }
    End
    {
    }
}