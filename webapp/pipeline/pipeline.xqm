module namespace _ = "pipeline/pipeline";
import module namespace xslt =  "http://basex.org/modules/xslt";

import module namespace PipeExec = 'de.axxepta.converterservices.proc.PipeExec';


declare
  %rest:GET
  %rest:path("/pipes/{$path}")
  %rest:query-param("input", "{$input}")
  %rest:query-param("inputPath", "{$inputPath}")
  %rest:query-param("outputPath", "{$outputPath}")
  %rest:query-param("workPath", "{$workPath}")
  %rest:query-param("asJob", "{$asJob}")
  %rest:query-param("jobId", "{$jobId}")
function _:exec-pipe($path as xs:string,
                    $input as xs:string?, $inputPath as xs:string?, $outputPath as xs:string?, $workPath as xs:string?
                    $asJob as xs:string?, $jobId as xs:string?)
{
    let $base-pipe := db:open('Pipes', $path)
    
    let $pipe := $base-pipe update {
      replace value of node ./pipeline/step[0] with if (empty($input)) then ./pipeline/step[0]/text() else $input
    } update {
      replace value of node ./pipeline/@inputPath with if (empty($inputPath)) then ./pipeline/@inputPath/value() else $inputPath
    } update {
      replace value of node ./pipeline/@workPath with if (empty($workPath)) then ./pipeline/@workPath/value() else $workPath
    } update {
      replace value of node ./pipeline/@outputPath with if (empty($outputPath)) then ./pipeline/@outputPath/value() else $outputPath
    }
    
    return if (not(empty($asJob) and lower-case($asJob) = 'true') then (
        if (empty($jobId)) then jobs:eval('PipeExec:execProcessString(serialize($pipe))')
            else jobs:eval('PipeExec:execProcessString(serialize($pipe))', map {'id' : $jobId})
    ) else (
        PipeExec:execProcessString(serialize($pipe))
    )
};