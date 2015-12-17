<#
.Synopsis
   ConvertTo-DSC allows you to get registry keys and values configured in existing GPOS
   and use that information to create DSC docuemnts.
.DESCRIPTION
   Group Policy Objects have been created, managed, configured, re-configured, deleted,
   backed up, imported, exported, inspected, detected, neglected and rejected for many years. 
   Now with the advent of Desired State Configuration (DSC) ensuring that the work previously 
   done with regards to configuring registry policy, is not lost. ConvertTo-DSC is a cmdlet 
   (advanced function) that was created to address this sceanario. 
.EXAMPLE
   ConvertTo-DSC -GPOName <gpo> -OutputFolder <folder where to create DSC .ps1 file>
.LINK
    Http://www.github.com/gpoguy
#>
function ConvertTo-DSC
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    
    Param
        ([Parameter(Mandatory=$true)]
        [string]$gpoName,
        [Parameter(Mandatory=$true)]
        [string] $outputFolder
    )

    Process
    {
    
        function ADMtoDSC
        {
            param
            ( 
               [String] $gpo,
               [String] $path
            )
            
            $policies = Recurse_PolicyKeys -key "HKLM\Software\Policies" -gpo $gpo
            # ADD SOME OUTPUT IF THERE IS NO SETTINGS IN THIS REGISTRY HIVE CONTINUE SILENTLY AND
            # MENTION IN VERBOSE OUTPUT "No settings in "HKLM\Software\Policies"

            $policies += Recurse_PolicyKeys -key "HKLM\Software\Microsoft\Windows NT\CurrentVersion" -gpo $gpo
            # ADD SOME OUTPUT IF THERE IS NO SETTINGS IN THIS REGISTRY HIVE CONTINUE SILENTLY AND
            # MENTION IN VERBOSE OUTPUT "No settings in "HKLM\Software\Microsoft\Winodws NT\CurrentVersion"

            #build the DSC configuration doc
            GenConfigDoc -path $path -gpo $gpo -policies $policies
        }

        # This function 
        function Recurse_PolicyKeys
        {
            param
            (
                [string]$key,
                [string]$gpoName
            )
            $current = Get-GPRegistryValue -Name $gpo -Key $key
            foreach ($item in $current)
            {
                if ($item.ValueName -ne $null)
                {
                    [array]$returnVal += $item
                }
                else
                {
                    Recurse_PolicyKeys -Key $item.FullKeyPath -gpoName $gpo
                }
            }
            return $returnVal
        }

        function GenConfigDoc
        {
            param
            (
                [string] $path,
                [string] $gpo,
                [array] $policies
            )
            #parse the spaces out of the GPO name, since we use it for the Configuration name
            $gpo = $gpo -replace " ","_"
            $outputFile = "$path\$gpo.ps1"
            "Configuration `"$gpo`"" | out-file -FilePath $outputFile
            '{' | out-file -FilePath $outputFile -Append
            'Node localhost' | out-file -FilePath $outputFile -Append
            '  {' | out-file -FilePath $outputFile -Append
            foreach ($regItem in $policies)
            {
                if ($regItem.FullKeyPath -eq $null) #throw away any blank entries
                {
                     continue
                }

                #now build the resources
                "    Registry `"" + $regItem.ValueName + "`""| out-file -FilePath $outputFile -Append
                '    {' | out-file -FilePath $outputFile -Append
                "      Ensure = `"Present`"" | out-file -FilePath $outputFile -Append
                "      Key = `""+ $regItem.FullKeyPath + "`""| out-file -FilePath $outputFile -Append
                "      ValueName = `"" + $regItem.ValueName + "`"" | out-file -FilePath $outputFile -Append
                "      ValueType = `"" +$regItem.Type + "`"" | out-file -FilePath $outputFile -Append
                "      ValueData = `"" +$regItem.Value + "`""| out-file -FilePath $outputFile -Append
                '    }' | out-file -FilePath $outputFile -Append
            }
            '  }' | out-file -FilePath $outputFile -Append
            '}' | out-file -FilePath $outputFile -Append
            $gpo | out-file -FilePath $outputFile -Append
        }

        ADMToDSC -gpo $gpoName -path $outputFolder
    }
}
