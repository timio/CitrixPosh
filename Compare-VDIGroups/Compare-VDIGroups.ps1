# Author: timio
# Filename: Compare-VDIGroups.ps1
# Last Modified Date: 6/19/2017

<#

.SYNOPSIS
    Compares VDI AD groups to find single user in multiple groups.
.DESCRIPTION
    Returns user information (SAM account, upn, firstname, lastname, matched AD Groups, and assigned Citrix Desktops) based on AD group membership supplied by the ADGroup parameter.  Outputs results in a text file to specifiec location using the FileLocation parameter.
.PARAMETER ADGroup
    Name of AD Security Group
.PARAMETER DeliveryController
    Delivery controller address
.PARAMETER FileLocation
    Path and filename of text file
.EXAMPLE
    Compare-VDIGroups -ADGroup "Group 1","Group 2","Group 3","Group 4" -DeliverController admincontrolleraddress.local -FileLocation C:\Desktop\file.txt

    Produces file specified in FileLocation parameter for all matched users.
#>

function Compare-VDIGroups
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
        [ValidatePattern( '.txt' )]
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

         #Loop through Groups and store values in single array        
         $Array_All = @()   
         foreach($name in $ADGroup){
         
            $sam = Get-ADGroupMember -Identity $name
            $Array_All += $sam.SamAccountName

         }
         
         
         #Compare values in Array_All and store matches in Array_same
         $Array_Same = @()
         $Array_Group = ($Array_All | group | ?{$_.Count -gt 1}).Values
         $Array_Same += $Array_Group
         

         #Retrieve Attributes for each user in array_same
         $matches = @()
         $objGroup = @()
         #Create comparable object according to adgroup param
         foreach($objADGroup in $ADGroup){
         
            $objGroupParam = New-Object System.Object
            $objGroupParam | Add-Member -MemberType NoteProperty -Name name -Value $objADGroup
            $objGroup += $objGroupParam
         
         }
         #Create matched object with all attributes for each match
         ## Get Domain prefix
         $netBiosName = Get-ADDomain | select NetBIOSName -ExpandProperty NetBIOSName
         $prefix = "$($netBiosName)" + "\"
         foreach($id in $Array_Same){
            
            $obj = New-Object System.Object
            $getAdUser = Get-ADUser -Filter{ SamAccountName -like $id } | select Name,UserPrincipalName,GivenName,Surname
            $obj | Add-Member -MemberType NoteProperty -Name SAMName -Value $getAdUser.Name
            $obj | Add-Member -MemberType NoteProperty -Name UPN -Value $getAdUser.UserPrincipalName
            $obj | Add-Member -MemberType NoteProperty -Name FirstName -Value $getAdUser.GivenName
            $obj | Add-Member -MemberType NoteProperty -Name LastName -Value $getAdUser.SurName
            $getAdPrincipalGroup = Get-ADPrincipalGroupMembership -Identity $id | select name
            $matchedGroups = Compare-Object -ReferenceObject $getAdPrincipalGroup -DifferenceObject $objGroup -Property name -IncludeEqual | ?{$_.SideIndicator -eq "=="} | select name -ExpandProperty name
            $obj | Add-Member -MemberType NoteProperty -Name MemberOf -Value $matchedGroups
            $assignedUser = $prefix + $id
            $getAssignedDesktops = Get-BrokerMachine -AdminAddress $DeliveryController -AssociatedUserName $assignedUser | select HostedMachineName -ExpandProperty HostedMachineName
            $obj | Add-Member -MemberType NoteProperty -Name AssignedDesktops -Value $getAssignedDesktops
            $matches += $obj   
         
         }

         $matches | Out-File $FileLocation -Force
    }
    End
    {
    }
}