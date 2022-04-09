$parm = @{
    Description = @"
Loops all `$connections childs
-Sets connectionName to the name of the connection, extracted from the connectionId
"@
    Alias       = "Raw.Set-Raw.Connections.ManagedApis.Name"
}

Task -Name "Set-Raw.Connections.ManagedApis.Name" @parm -Action {
    if ($PsLaFilePath) { $Script:filePath = $PsLaFilePath }
    $filePath = Set-TaskWorkDirectory -Path $PsLaWorkPath -FilePath $Script:filePath
    
    $lgObj = Get-TaskWorkObject -FilePath $Script:filePath
    $lgObj.properties.parameters.'$connections'.value.PsObject.Properties | ForEach-Object {
        if ($_.Value.id -like "*managedApis*") {
            $conName = $_.Value.connectionId.Split("/") | Select-Object -Last 1
            $_.Value.connectionName = $conName
        }
    }

    Out-TaskFile -Path $filePath -InputObject $([LogicApp]$lgObj)
}