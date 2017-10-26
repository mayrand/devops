#set-Item wsman:\localhost\client\trustedhosts -Value 'jenkins,10.0.2.79'
param
(
	[string]$configPath = '..\sampleIis.json', #$(throw 'Please specify config file path.')
	[string]$serverName = '10.0.2.79' #$(throw 'Please specify server name.')
)

$session = New-PSSession -ComputerName $serverName -Authentication NegotiateWithImplicitCredential;

$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop;

$config = Get-Content $configPath -Raw | ConvertFrom-Json;

$block = {

	$config = $args[0];
	
	import-module 'webAdministration' 

	# creating application pools
	function Create-AppPool([string]$appPoolName, [string]$netVersion)
	{
		$appPool = Get-Item ("IIS:\AppPools\" + $appPoolName) -ErrorAction SilentlyContinue;
		if ($appPool -eq $null)
		{
			"Application pool $appPoolName does not exists, creating..." | Write-Host -ForegroundColor Yellow -NoNewline;
			$a = (New-WebAppPool -Name $appPoolName);
			Set-ItemProperty ("IIS:\AppPools\" + $appPoolName) -Name managedRuntimeVersion -Value $netVersion;
			"OK" | Write-Host -ForegroundColor Green;
		}
		else
		{
			"Application pool $appPoolName exists..." | Write-Host -ForegroundColor Green;
		}
	}

	# creating websites
	function Create-Website([string]$siteName, [string]$appPool, [string]$sitePath)
	{
		$site = Get-Item ("IIS:\Sites\" + $siteName) -ErrorAction SilentlyContinue;
		if ($site -eq $null)
		{
			CheckExistCreateDir -path $sitePath
			"Web site $siteName does not exists, creating with location $sitePath..." | Write-Host -ForegroundColor Yellow -NoNewLine;
			$w = (New-Website -Name $siteName -ApplicationPool $appPool -PhysicalPath $sitePath);
			"OK" | Write-Host -ForegroundColor Green;
		}
		else 
		{
			"Web site $siteName exists with location $sitePath..." | Write-Host -ForegroundColor Green;
		}
	}

	# creating binding
	function Create-Binding([string]$websiteName, [string]$protocol, [string]$port, [string]$ip)
	{
		$bind = Get-WebBinding -Name $websiteName -IPAddress $ip -Port $port -Protocol $protocol
		if ($bind -eq $null)
		{
			"Binding $protocol/$ip/$port/$websiteName does not exists, creating..." | Write-Host -ForegroundColor Yellow -NoNewLine;
			New-WebBinding -Protocol $protocol -Name $websiteName -IPAddress $ip -Port $port;
			"OK" | Write-Host -ForegroundColor Green;
		}
		else 
		{
			"Binding $protocol/$ip/$port/$websiteName exists" | Write-Host -ForegroundColor Green;
		}
	}

	function Create-App ([string]$url, [string]$websiteName, [string]$appPoolName, [string]$path)
	{
		$application = Get-WebApplication -Site $websiteName -Name $url
		if($application -eq $null)
		{
			CheckExistCreateDir -path $path
			"App $websiteName$url does not exist creating...." | Write-Host -ForegroundColor Yellow -NoNewLine;
			$a = (New-WebApplication -Name $url -Site $websiteName -ApplicationPool $appPoolName -PhysicalPath $path);
			"OK" | Write-Host -ForegroundColor Green;
		}
		else 
		{
			"App $websiteName$url exists" | Write-Host -ForegroundColor Green;
		}
	}

	function CheckExistCreateDir([string]$path)
	{
		if ((Test-Path -Path $path) -ne $True)
		{
			"Path $path does not exists, creating..." | Write-Host -ForegroundColor Yellow -NoNewline;
			$newDir = New-Item $path -type directory;
			"OK" | Write-Host -ForegroundColor Green;
		}
		else
		{
			"Path $path exists" | Write-Host -ForegroundColor Green;
		}
	}

	foreach($apppool in $config.AppPools)
	{
		Create-AppPool -appPoolName $apppool.Name -netVersion $apppool.NetVersion;
	}
	foreach($website in $config.Websites)
	{
		Create-Website -siteName $website.Name -appPool $website.AppPoolName -sitePath $website.Path;
		foreach($binding in $website.Bindings)
		{
			Create-Binding -websiteName $website.Name -protocol $binding.Protocol -port $binding.Port -ip $binding.IPAddress;
		}
		foreach($app in $website.Apps)
		{
			Create-App -url $app.Url -websiteName $website.Name -appPoolName $app.AppPoolName -path $app.Path;
		}
	}
}

Invoke-Command -Session $session -ScriptBlock $block -ArgumentList $config;