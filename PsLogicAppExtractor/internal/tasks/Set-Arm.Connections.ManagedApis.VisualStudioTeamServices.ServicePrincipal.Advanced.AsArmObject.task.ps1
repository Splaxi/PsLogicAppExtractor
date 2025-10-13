$parm = @{
    Description = @"
Loops all `$connections children
-Validates that is of the type Azure DevOps / Visual Studio Team Services
--Creates a new resource in the ARM template, for the ApiConnection object
--With matching ARM Parameters, for the Namespace
--Makes sure the ARM Parameters logicAppLocation exists
--The type is based on the Service Principal authentication
--Name & Display Name is extracted from the connection object
Requires an authenticated session, either Az.Accounts or az cli
"@
    Alias       = "Arm.Set-Arm.Connections.ManagedApis.VisualStudioTeamServices.ServicePrincipal.Advanced.AsArmObject"
}

Task -Name "Set-Arm.Connections.ManagedApis.VisualStudioTeamServices.ServicePrincipal.Advanced.AsArmObject" @parm -Action {
    Set-TaskWorkDirectory

    # We can either use the az cli or the Az modules
    $tools = Get-PSFConfigValue -FullName PsLogicAppExtractor.Execution.Tools

    $found = $false
    $conType = "visualstudioteamservices"
    
    $armObj = Get-TaskWorkObject

    foreach ($connectionObj in $armObj.resources[0].properties.parameters.'$connections'.value.PsObject.Properties) {
        if ($connectionObj.Value.id -like "*managedApis/visualstudioteamservices*") {
            $found = $true

            # Fetch the details from the connection object
            $uri = "{0}?api-version=2018-07-01-preview" -f $($connectionObj.Value.connectionId)

            if ($tools -eq "AzCli") {
                $resObj = az rest --url $uri | ConvertFrom-Json
            }
            else {
                $resObj = Invoke-AzRestMethod -Path $uri -Method Get | Select-Object -ExpandProperty content | ConvertFrom-Json
            }

            # Use the display name as the name of the resource
            $conName = $resObj.Properties.DisplayName

            $tenantId = $resObj.properties.parameterValueSet.values."token:TenantId".value
            $clientId = $resObj.properties.parameterValueSet.values."token:clientId".value

            # Fetch base template
            $pathArms = "$(Get-PSFConfigValue -FullName PsLogicAppExtractor.ModulePath.Base)\internal\arms"
            $apiObj = Get-Content -Path "$pathArms\API.AzureDevOps.ServicePrincipal.json" -Raw | ConvertFrom-Json

            # Set the names of the parameters
            $Prefix = Get-PSFConfigValue -FullName PsLogicAppExtractor.prefixsuffix.connection.prefix
            $parmApicId = Format-Name -Type "Connection" -Prefix $Prefix -Value "$($connectionObj.Name)"
            $parmApicTenant = Format-Name -Type "Connection" -Prefix $Prefix -Suffix "_TenantId" -Value "$($connectionObj.Name)"
            $parmApicClient = Format-Name -Type "Connection" -Prefix $Prefix -Suffix "_ClientId" -Value "$($connectionObj.Name)"
            $parmApicSecret = Format-Name -Type "Connection" -Prefix $Prefix -Suffix "_ClientSecret" -Value "$($connectionObj.Name)"
            
            # $idPreSuf = Format-Name -Type "Connection" -Value "$($_.Name)"
            # $displayPreSuf = Format-Name -Type "Connection" -Prefix $Prefix -Suffix "_DisplayName" -Value "$($_.Name)"
            
            $armObj = Add-ArmParameter -InputObject $armObj -Name "$parmApicId" `
                -Type "string" `
                -Value $conName `
                -Description "The name / id of the ManagedApi connection object that is being utilized by the Logic App. Will be for the trigger and other actions that depend on connections."
                
            $armObj = Add-ArmParameter -InputObject $armObj -Name "$parmApicTenant" `
                -Type "string" `
                -Value "$tenantId" `
                -Description "The Azure tenant id that the Azure DevOps instance is connected to. ($($_.Name))"

            $armObj = Add-ArmParameter -InputObject $armObj -Name "$parmApicClient" `
                -Type "string" `
                -Value "$clientId" `
                -Description "The ClientId used to authenticate against the Azure DevOps instance. ($($_.Name))"

            $armObj = Add-ArmParameter -InputObject $armObj -Name "$parmApicSecret" `
                -Type "SecureString" `
                -Value "" `
                -Description "The ClientSecret used to authenticate against the Azure DevOps instance. ($($_.Name))"
                
            # Update the api object properties
            $apiObj.Name = "[parameters('$parmApicId')]"
            $apiObj.properties.displayName = "[parameters('$parmApicId')]"
            $apiObj.properties.parameterValueSet.values."token:TenantId".value = "[parameters('$parmApicTenant')]"
            $apiObj.properties.parameterValueSet.values."token:clientId".value = "[parameters('$parmApicClient')]"
            $apiObj.properties.parameterValueSet.values."token:clientSecret".value = "[parameters('$parmApicSecret')]"

            # Append the new resource to the ARM template
            $armObj.resources += $apiObj

            if ($null -eq $armObj.resources[0].dependsOn) {
                # Create the dependsOn array if it does not exist
                $armObj.resources[0] | Add-Member -MemberType NoteProperty -Name "dependsOn" -Value @()
            }

            # Add the new resource to the dependsOn array, so that the deployment will work
            $armObj.resources[0].dependsOn += "[resourceId('Microsoft.Web/connections', parameters('$parmApicId'))]"

            # Adjust the connection object to depend on the same name
            $connectionObj.Value.connectionId = "[resourceId('Microsoft.Web/connections', parameters('$parmApicId'))]"
            $connectionObj.Value.connectionName = "[parameters('$parmApicId')]"
            $connectionObj.Value.id = "[format('/subscriptions/{0}/providers/Microsoft.Web/locations/{1}/managedApis/$conType', subscription().subscriptionId, parameters('logicAppLocation'))]"
        }
    }

    if ($found) {
        if ($null -eq $armObj.parameters.logicAppLocation) {
            $armObj = Add-ArmParameter -InputObject $armObj -Name "logicAppLocation" `
                -Type "string" `
                -Value "[resourceGroup().location]" `
                -Description "Location of the Logic App. Best practice recommendation is to make this depending on the Resource Group and its location."
        }
    }

    Out-TaskFileArm -InputObject $armObj
}