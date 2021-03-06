
function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	<#
	$returnValue = @{
		OctopusURL = [System.String]
		OctopusAPIKey = [System.String]
		ProjectTR = [System.String]
		ProjectEnv = [System.String]
	}

	$returnValue
	#>
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."

	#Include this line if the resource requires a system reboot.
	#$global:DSCMachineStatus = 1


    Begin
    {
        # Set verbose preferences
        $VerbosePreference = "Continue"
		#Checks Tentacle helth
		Write-Verbose -Message 'Runing Tentacle health check...'
		Start-TentacleHeathCheck -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
		Write-Verbose -Message 'Checking if Calamari has been successfully deployed...'
		# Check Deploys Calamari if it doesnt exist
		If (!(Test-Path -Path 'C:\Octopus\Calamari\*\Success.txt')) {
        Write-Verbose -Message 'Calamari has not been successfully deployed...' -Verbose
        Write-Verbose -Message 'Deploying Calamari' -Verbose
        Set-CalamariUpgrade -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
        } Else {
        Write-Verbose 'Calamari has been deployed' -Verbose}
		
        Write-Verbose -Message 'Testing if octo.exe exist'
        If (!(Test-Path -Path "C:\Temp\OctopusTools\Octo.exe")) {
        Write-Verbose -Message 'Octo.exe tool does not exist' -Verbose
        Write-Verbose "Downloading latest Octopus Tools from $CommandLineToolsURL to $CommandLineToolsPath"
        Get-OctopusCommandLineTools $CommandLineToolsURL $CommandLineToolsPath
        } Else {
        Write-Verbose 'Octo.exe exists'}
		$IISExistingWebSites = Get-Website | Select-Object -ExpandProperty name
        New-Alias -Name Octo -Value "C:\Temp\OctopusTools\Octo.exe" -Force
        
		$ProjectListVersion = Get-LatestProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectEnv $ProjectEnv
        $ProjectsList = Get-OctopusProjectsIISWebSiteNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $IISProjectID =  Get-IISWebSiteNamesandProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $ProjectIDIISnames= Get-ProjectIDandNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
		
		$ProjectListString = $ProjectList |Out-String
        Write-Verbose -Message "Latest releasese to $ProjectEnv environment: $ProjectListString" -Verbose

        }
        Process
        {

        $websites = @()
	    foreach ($website in $IISExistingWebSites) {
	        if ($website -ne "Default Web Site"){
			        $websites += $website
		        }
        }

	    #### Finds out the missing projects###
	    Write-Verbose "Comparing project list" -Verbose
        $ProjectsMissing = Compare-Object $ProjectsList $websites | Where  SideIndicator -EQ "<=" | Select-Object -ExpandProperty InputObject
        If ($ProjectsMissing -gt 0) {
					
	    Write-Verbose "Setting Up the following Projects: $ProjectsMissing" -Verbose
                    
        foreach ($OctopusProject in $ProjectsMissing) {
        Write-Verbose "creating Missing project ID and Missing Project Names" -Verbose

        $MissingProjectID =  $IISProjectID.get_item($OctopusProject)
        $MissingProjectName = $ProjectIDIISnames.get_item($MissingProjectID)
        $MissingProjectVersion = $ProjectListVersion.get_item($OctopusProject)

        Write-Verbose "Starting to deploy projects" -Verbose

        $OctoAlias = Get-Alias octo |Select-Object -ExpandProperty Definition

        Write-Verbose "Set location to C:\Temp\OctopusTools\" -Verbose

        Push-Location "C:\Temp\OctopusTools\"

        if ( $OctopusProject -gt 0 -and $MissingProjectID -gt 0 -and $MissingProjectName -gt 0 -and $MissingProjectVersion -gt 0) {

        try{
           Invoke-AndAssert { & .\Octo.exe deploy-release --project $MissingProjectName --version $MissingProjectVersion --deployto $ProjectEnv --specificmachines=$env:computername --server $OctopusURL --apiKey $OctopusAPIKey}
        
                } catch {
                           $ErrorMessage = $_.Exception.Message
                           Write-Host -ForegroundColor Red -BackgroundColor Yellow - $_.Exception.Message $ErrorMessage
                           }

            } else {Write-Verbose -Message " $OctopusProject cannot be deployed becaues it is missing one of the maditory varaibles PROJECT ID or PROJECT NAME or PROJECT VERSION NUMBER" -Verbose }
        
        
        }
        
        } Else {Write-Verbose -Message 'Nothing to deploy' -Verbose}


    }    
	End
    {
        Start-Sleep -Seconds 5

	    $IISWebsites = Get-Website | Select-Object -ExpandProperty name
					
	    Write-Verbose "Websites/Projects running on this node: $IISWebsites "
    }




}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv
	)

	#Write-Verbose "Use this cmdlet to deliver information about command processing."

	#Write-Debug "Use this cmdlet to write debug information while troubleshooting."


	<#
	$result = [System.Boolean]
	
	$result
	#>



        Write-Verbose -Message 'Testing if octo.exe exist'
        If (!(Test-Path -Path "C:\Temp\OctopusTools\Octo.exe")) {
        Write-Verbose -Message 'Octo.exe tool does not exist'
		return $false
        } Else {
        Write-Verbose 'Octo.exe exists'}
        $IISExistingWebSites = Get-Website | Select-Object -ExpandProperty name
        New-Alias -Name Octo -Value "C:\Temp\OctopusTools\Octo.exe" -Force
        $ProjectsList = Get-OctopusProjectsIISWebSiteNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $IISProjectID =  Get-IISWebSiteNamesandProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $ProjectIDIISnames= Get-ProjectIDandNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey


                    
        $websites = @()
	    foreach ($website in $IISExistingWebSites) {
	        if ($website -ne "Default Web Site"){
			        $websites += $website
		        }
        }
         #### Finds out the missing projects###
	    Write-Verbose "Comparing project list 2" -Verbose
        $ProjectsMissing = Compare-Object $ProjectsList $websites | Where  SideIndicator -EQ "<=" | Select-Object -ExpandProperty InputObject
        Write-Verbose -Message "projects missing $ProjectsMissing"

        Write-Verbose -Message 'tested if something missing01'

        If ($ProjectsMissing -gt 0) {return $false}
        else {Write-Verbose -Message 'Node has all necesary projects running. Nothing to deploy'
        return $true}

        Write-Verbose -Message 'tested if something missing'

}


function Get-EnvironmentID
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey

    )

	Write-Verbose -Message 'Building environment name and environment ID hash table' -Verbose
    

    $Environments = Invoke-RestMethod -Verbose:$false $OctopusURL/api/environments -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items

    $Environments | Select-Object Name, ID | % { $EnvironmentHashTable = @{} } { $EnvironmentHashTable[$_.Name] = $_.ID}

    return $EnvironmentHashTable
}

#Get-EnvironmentID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey

#$EnvironmentID.get_item("PROD")

function Get-EnvironmentTarget
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey
    )

Write-Verbose -Message 'Building environment name and Project ID target roles hash table' -Verbose

Write-verbose "Retrieving projects"
$Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items
Write-verbose "Building deployment process API list"
$DeploymentProcesses=$Projects.links.DeploymentProcess

#Write-Host "Building project ID and target roles hash table"
foreach ($Processes in $DeploymentProcesses) {


$ProjectNameTargetHash = @{}

$ProjectID = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }) | select -expand ProjectID

$ProjectTargetRole = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }).Steps.Properties."Octopus.Action.TargetRoles" | select -First 1

$ProjectNameTargetHash.Add($ProjectID, $ProjectTargetRole)

$ProjectTargerHash += $ProjectNameTargetHash

    
}



# Project ID targer Hash tabale 
return $ProjectTargerHash
}

#Get-EnvironmentTarget -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey


function Get-ProjectIDEnvironment
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey   

    )

Write-Verbose -Message 'Building project ID and environment ID hash table' -Verbose


$Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items
$DeploymentProcesses=$Projects.links.DeploymentProcess


foreach ($Processes in $DeploymentProcesses) {

$ProjectNameEnvironmentsHash = @{}

$ProjectID = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }) | select -expand ProjectID
$Step = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }).steps | select -First 1
$ProjectEnvironment = $Step.Actions.Environments


$ProjectNameEnvironmentsHash.Add($ProjectID, $ProjectEnvironment)

$ProjectEnvironmentHash += $ProjectNameEnvironmentsHash
    
}

return $ProjectEnvironmentHash

}


#Get-ProjectIDEnvironment -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey


function Get-OctopusProjectsIISWebSiteNames
{

    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv  

    )

    
        $EnvironmentID = Get-EnvironmentID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
        $EnvironmentTarget = Get-EnvironmentTarget -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey 
        $ProjectIDEnvironment = Get-ProjectIDEnvironment -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey

	    $Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items
        $DeploymentProcesses=$Projects.links.DeploymentProcess
		$ReturnWebSitesList = @()

foreach ($Processes in $DeploymentProcesses) {



$ProjectID = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }) | select -expand ProjectID
$Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items
$DeploymentProcesses=$Projects.links.DeploymentProcess

If ($ProjectIDEnvironment.Item($ProjectID) -contains $EnvironmentID.Item($ProjectEnv) -and $EnvironmentTarget.Item($ProjectID) -contains $ProjectTR ) { 

$Websitestemp = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Processes" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }).Steps.Actions.Properties."Octopus.Action.IISWebSite.WebSiteName"

	    foreach ($item in $Websitestemp) {

            if ($item -gt 0) {

            $ReturnWebSitesList +=$item

                }
                

				}
	
			}


		}
	return $ReturnWebSitesList





}

#Get-OctopusProjectsIISWebSiteNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv


function Get-IISWebSiteNamesandProjects
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv  
    )

    Begin
    {
    $EnvironmentIDHash = Get-EnvironmentID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey

    }
    Process
    {
    $Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects/all -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } 
    $ProjectList=$Projects.name
    $DeploymentProcesses = $Projects.links.DeploymentProcess

    foreach ($Process in $DeploymentProcesses){
    

            $Steps=Invoke-RestMethod -Verbose:$false $OctopusURL/$Process -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey }  | Select-Object -ExpandProperty Steps
            
            $StepRole = $steps.properties."Octopus.Action.TargetRoles" | Select-Object -First 1
            
            $Actions=Invoke-RestMethod -Verbose:$false $OctopusURL/$Process -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey }  | Select-Object -ExpandProperty Steps

            $Environments = $Actions.actions.environments | Sort-Object -Unique
            
            

                            if ($Environments -contains  $EnvironmentIDHash.get_item($ProjectEnv) -and $StepRole -contains $ProjectTR ) {
                            $table = @{}

                            $IISName = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Process" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }).Steps.Actions.Properties."Octopus.Action.IISWebSite.WebSiteName"


                                    foreach ($item in $IISName) {

                                            if ($item -gt 0) {
                                                $WebSiteName = $null
                                                $WebSiteName +=$item
                                                 }
                                            }

                            #Write-Output $WebSiteName

                            $ProjectID = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Process" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }).ProjectID

                            #Write-Output $ProjectID
            
            
                            $table.add($WebSiteName, $ProjectID)
                            $Table01 += $table
                            
                            Continue
            

                            }



      


            

    }

    return $Table01 

    }

}

#Get-IISWebSiteNamesandProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv


function Get-ProjectIDandNames
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey
        

    )

Write-Verbose -Message 'Building project ID and Project name hash table' -Verbose


$Projects = Invoke-RestMethod -Verbose:$false $OctopusURL/api/projects -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items
$SelfProjects=$Projects.links.self


foreach ($Self in $SelfProjects) {

$ProjectIDNameHash = @{}

$ProjectID = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Self" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }) | select -expand ID
$ProjectName = (Invoke-RestMethod -Verbose:$false -Method Get -Uri "$OctopusURL/$Self" -Header @{ "X-Octopus-ApiKey" = $OctopusAPIKey }) | select -expand Name

$ProjectIDNameHash.Add($ProjectID, $ProjectName)

$ProjectIDNameHashTable += $ProjectIDNameHash
    
}

return $ProjectIDNameHashTable

}

#Get-ProjectIDandNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey



function Set-OctopusProjects
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectTR,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv
    )

    Begin
    {
        $IISExistingWebSites = Get-Website | Select-Object -ExpandProperty name
        Set-Location "C:\Temp\OctopusTools\"

        $ProjectsList = Get-OctopusProjectsIISWebSiteNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $IISProjectID =  Get-IISWebSiteNamesandProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv
        $ProjectIDIISnames= Get-ProjectIDandNames -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
        }
        Process
        {
        $websites = @()
	    foreach ($website in $IISExistingWebSites) {
	        if ($website -ne "Default Web Site"){
			        $websites += $website
		        }
        }

	    #### Finds out the missing projects###
	    Write-Verbose "Comparing project list" -Verbose
        $ProjectsMissing = Compare-Object $ProjectsList $websites | Where  SideIndicator -EQ "<=" | Select-Object -ExpandProperty InputObject
        If ($ProjectsMissing -gt 0) {
					
	    Write-Verbose "Setting Up the following Projects: $ProjectsMissing" -Verbose
                    
        foreach ($OctopusProject in $ProjectsMissing) {

        $MissingProjectID =  $IISProjectID.get_item($OctopusProject)
        $MissingProjectName = $ProjectIDIISnames.get_item($MissingProjectID)

        Invoke-AndAssert { & .\Octo.exe deploy-release --project $MissingProjectName --version=latest --deployto $ProjectEnv --specificmachines=$env:computername --server $OctopusURL --apiKey $OctopusAPIKey}
        }
	    $IISWebsites = Get-Website | Select-Object -ExpandProperty name
					
	    Write-Verbose "Websites/Projects running on this node: $IISWebsites "
        } Else {Write-Verbose -Message 'Nothing to deploy' -Verbose}


    }
    End
    {
    }
}


#Set-OctopusProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectTR $ProjectTR -ProjectEnv $ProjectEnv


function Invoke-AndAssert {
    param ($block) 
  
    & $block | Write-Verbose
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) 
    {
        throw "Command returned exit code $LASTEXITCODE"
    }
}


function Request-File 
{
    param (
        [string]$url,
        [string]$saveAs
    )
 
    Write-Verbose "Downloading $url to $saveAs"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $saveAs)
}

<##

function Expand-ZIPFile
{
    [CmdletBinding()]
    Param
    (

        $Path,
        $DestinationPath
    )

    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($Path)
    
    foreach($item in $zip.items())
        {
        $shell.Namespace($DestinationPath).copyhere($item)
        }
}

##>

function Get-OctopusCommandLineTools
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        $Param1,

        # Param2 help description
        $Param2
    )

    Begin
    {
        $CommandLineToolsURL = "https://octopus.com/downloads/latest/CommandLineTools"
        $CommandLineToolsPath = "$($env:SystemDrive)\temp\OctopusTools.zip"
        $CommandLineToolsPathUnZipped = "$($env:SystemDrive)\Temp\OctopusTools\octo.exe"

    
    }
    Process
    {
        
    mkdir "$env:SystemDrive\temp" -ErrorAction SilentlyContinue

    
    if (!(test-path $CommandLineToolsPath)) {
        Request-File $CommandLineToolsURL $CommandLineToolsPath
    }
    
    
	if(Test-Path $CommandLineToolsPathUnZipped){
		 Remove-Item -Path C:\Temp\OctopusTools -Recurse -Force}


	if(!(Test-Path $CommandLineToolsPathUnZipped)){
		Write-Verbose -Message 'Creating Octopus Tools Diretectory'
		 New-Item -Path c:\temp\OctopusTools  -ItemType directory -Force
		Write-Verbose -Message 'UnZipping Octopus Tools...'
		# Expand-ZIPFile -Path $CommandLineToolsPath -DestinationPath "$env:SystemDrive\temp\OctopusTools"
		Expand-Archive -LiteralPath $CommandLineToolsPath -DestinationPath "$env:SystemDrive\temp\OctopusTools"
	}
    
    }
    
}


function Get-LatestProjects
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey,

		[parameter(Mandatory = $true)]
		[System.String]
		$ProjectEnv  
    )

    Begin
    {
		Import-Module -Name OctoPosh

		$env:OctopusURL = $OctopusURL
		$env:OctopusAPIKey = $OctopusAPIKey
       		
    }
    Process
    {
        $LatestDeployments = Get-OctopusEnvironment -Name $ProjectEnv -Verbose:$false | Select -ExpandProperty LatestDeployment | Select-Object ProjectName, ReleaseVersion
        foreach ($dep in $LatestDeployments ) {
        $EmptyHash = @{}
        $EmptyHash.add($dep.ProjectName, $dep.ReleaseVersion)
        $DeploymentHash +=$EmptyHash
        }

    }
    End
    {
    
    return $DeploymentHash
    
    }
	
}

#$ProjectList = Get-LatestProjects -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -ProjectEnv $ProjectEnv


function Get-MachineNameID
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([Hashtable])]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey
    )

Write-Verbose -Message 'Building Machine name and Machine ID hash table' -Verbose

Write-verbose "Retrieving machines"
$Machines = Invoke-RestMethod -Verbose:$false $OctopusURL/api/machines -Headers @{ "X-Octopus-ApiKey" = $OctopusAPIKey } | Select -ExpandProperty Items

foreach ($Machine in $Machines) {


$MachineNameID = @{}

$MachineNameID.Add($Machine.Name, $Machine.ID)

$MachineNameIDHash += $MachineNameID

    
}



# Project ID targer Hash tabale 
return $MachineNameIDHash
}

#$MachineID = Get-MachineNameID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
#$MachineID.get_item($env:COMPUTERNAME)

function Set-CalamariUpgrade
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey
    )

    Begin
    {
    #Adding libraries

    Add-Type -Path "C:\Program Files\Octopus Deploy\Tentacle\Octopus.Client.dll"

    #Creating a connection
    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURL,$OctopusAPIKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint
    }
    Process
    {
    $MachineIDs = Get-MachineNameID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
    $MachineID = $MachineIDs.get_item($env:COMPUTERNAME)

		# this command starts the Calamari deployment
		Write-Verbose -Message 'Deploying Calamari...'
		$repository.Tasks.ExecuteCalamariUpdate("Pre-load latest calamari - Trigered by PS DSC", "$MachineID")

    }
    End
    {
    }
}

#Set-CalamariUpgrade -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -Verbose


function Start-TentacleHeathCheck
{
    [CmdletBinding()]
    [Alias()]
    Param
    (
		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusURL,

		[parameter(Mandatory = $true)]
		[System.String]
		$OctopusAPIKey
    )

    Begin
    {
    #Adding libraries
    Add-Type -Path "C:\Program Files\Octopus Deploy\Tentacle\Octopus.Client.dll"

    #Creating a connection
    $endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURL,$OctopusAPIKey
    $repository = new-object Octopus.Client.OctopusRepository $endpoint
    }
    Process
    {
    $MachineIDs = Get-MachineNameID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey
    $MachineID = $MachineIDs.get_item($env:COMPUTERNAME)

	$EnvironmentIDs = Get-EnvironmentID -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey

	$EnvironmentID = $EnvironmentIDs.get_item($ProjectEnv)

		# this command starts machines's health check
		Write-Verbose -Message 'Running healt check.'
		$repository.Tasks.ExecuteHealthCheck("Health Check - Trigered by PS DSC","1","1","$EnvironmentID","$MachineID")
		Start-Sleep -Seconds 3
    }
    End
    {
    }
}


#Start-TentacleHeathCheck -OctopusURL $OctopusURL -OctopusAPIKey $OctopusAPIKey -Verbose


Export-ModuleMember -Function *-TargetResource

