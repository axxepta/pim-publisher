module namespace _ = "scheduling/pipeline";

import module namespace PipeExec = 'de.axxepta.converterservices.proc.PipeExec';

(: start pipeline from Pipes database, optionally as job, optionally as service (with standard interval 1D) :)
declare
  %rest:GET
  %output:method("text")
  %rest:path("/pipes/{$path}")
  %rest:query-param("input", "{$input}", "")
  %rest:query-param("inputPath", "{$inputPath}", "")
  %rest:query-param("outputPath", "{$outputPath}", "")
  %rest:query-param("workPath", "{$workPath}", "")
  %rest:query-param("asJob", "{$asJob}")
  %rest:query-param("id", "{$id}")
  %rest:query-param("service", "{$service}")
  %rest:query-param("start", "{$start}")
  %rest:query-param("interval", "{$interval}")
function _:start-pipe($path as xs:string,
                    $input as xs:string?, $inputPath as xs:string?, $outputPath as xs:string?, $workPath as xs:string?,
                    $asJob as xs:string?, $id as xs:string?, $service as xs:string?, $start as xs:string?, $interval as xs:string?){
    if (db:exists('Pipes', $path)) then (
        if (not(empty($asJob)) and lower-case($asJob) = 'true') then (
            let $args := string-join( ($path, $input, $inputPath, $outputPath, $workPath), "','")
            return if (empty($service) or lower-case($service) != 'true') then
                if (empty($id))
                    then jobs:eval("import module namespace sched = 'scheduling/pipeline' at 'pipeline.xqm'; sched:exec-pipe('" || $args || "')")
                    else jobs:eval("import module namespace sched = 'scheduling/pipeline' at 'pipeline.xqm'; sched:exec-pipe('" || $args || "')",
                        (), map{ 'id': $id })
            else
                if (empty($id))
                    then jobs:eval("import module namespace sched = 'scheduling/pipeline' at 'pipeline.xqm'; sched:exec-pipe('" || $args || "')",
                        (),
                        map{ 'service': true(), 'start': if (empty($start)) then 'PT0S' else $start, 'interval': if (empty($interval)) then 'P1D' else $interval })
                    else jobs:eval("import module namespace sched = 'scheduling/pipeline' at 'pipeline.xqm'; sched:exec-pipe('" || $args || "')",
                        (),
                        map{ 'service': true(), 'start': if (empty($start)) then 'PT0S' else $start, 'interval': if (empty($interval)) then 'P1D' else $interval, 'id': $id })
        ) else (
           let $res := _:exec-pipe($path, $input, $inputPath, $outputPath, $workPath)
           return "exec pipe " || $path
        )
    ) else 'No such pipeline file!'
};
  
declare function _:exec-pipe($path as xs:string,
                    $input as xs:string?, $inputPath as xs:string?, $outputPath as xs:string?, $workPath as xs:string?)
{         
    if (db:exists('Pipes', $path)) then (
        let $base-pipe := db:open('Pipes', $path)
        
        let $x := admin:write-log('Starting pipe ' || $path)
        
        let $pipe := $base-pipe update {
          replace value of node ./pipeline/step[1]/input[1] with if (empty($input) or $input = "") then ./pipeline/step[1]/input[1]/text() else $input
        } update {
          replace value of node ./pipeline/@inputPath with if (empty($inputPath) or $input = "") then ./pipeline/@inputPath/string() else $inputPath
        } update {
          replace value of node ./pipeline/@workPath with if (empty($workPath) or $input = "") then ./pipeline/@workPath/string() else $workPath
        } update {
          replace value of node ./pipeline/@outputPath with if (empty($outputPath) or $input = "") then ./pipeline/@outputPath/string() else $outputPath
        }
        (:return admin:write-log($pipe):)
        (:return PipeExec:execProcessString(serialize($pipe)):)
        
        let $request := <http:request href='http://localhost:9894/spark/pipeline-async'
            method='post' username='admin' password='admin' send-authorization='true'>
            <http:body media-type='application/xml'>{$pipe}</http:body>
          </http:request>
        return http:send-request($request)
    ) else 'No such pipeline file!'
};


declare
  %rest:POST("{$content}")
  %rest:path("/log")
function _:admin-log($content) {
    admin:write-log($content)
};


declare
  %rest:GET
  %rest:path("/pipe-test")
function _:pipe-test() {
    let $pipe := db:open('Pipes', 'testpipe_imagefilter.xml')
    let $request :=
      <http:request href='http://localhost:9894/spark/pipeline'
        method='post' username='admin' password='admin' send-authorization='true'>
        <http:body media-type='application/xml'>{$pipe}</http:body>
      </http:request>
    return http:send-request($request)
};


declare
  %rest:GET
  %rest:path("/exec-pipe-test")
function _:exec-pipe-test() {
    let $request :=
      <http:request method='get' href='{'http://localhost:9894/pipes/testpipe_imagefilter.xml?inputPath=' || encode-for-uri('E:\Dateien\Projekte\Syncrovet\Demodaten_icecat')}'
        username='admin' password='admin' send-authorization='true'/>
    return http:send-request($request)
};