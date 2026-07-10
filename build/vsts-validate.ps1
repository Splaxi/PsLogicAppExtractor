# Guide for available variables and working with secrets:
# https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=powershell

# Needs to ensure things are Done Right and only legal commits to master get built

param (
	$TestGeneral = $true,

	$TestFunctions = $true,

	$Include = "*",

	$Exclude = "*.exclude.ps1"
)

# Run internal pester tests
& "$PSScriptRoot\..\PsLogicAppExtractor\tests\pester.ps1" -TestGeneral $TestGeneral -TestFunctions $TestFunctions -Include $Include -Exclude $Exclude