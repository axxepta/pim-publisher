module namespace _ = "scheduling/scheduling";


declare
  %rest:POST("{$query}")
  %rest:path('/jobs/daily-job')
  %rest:query-param("time", "{$time}")
  %rest:query-param("id", "{$id}")
function _:daily-job($query, $time as xs:string, $id as xs:string) {
  jobs:eval($query, (), map { 'start': $time, 'interval': 'P1D', 'id': $id })
};

declare
  %rest:POST("{$query}")
  %rest:path('/jobs/hourly-job')
  %rest:query-param("time", "{$time}")
  %rest:query-param("id", "{$id}")
function _:hourly-job($query, $time as xs:string, $id as xs:string) {
  jobs:eval($query, (), map { 'start': $time, 'interval': 'P1H', 'id': $id })
};

declare
  %rest:GET
  %rest:path('/jobs/{$id}/stop') 
function _:stop-job($id) {
  jobs:stop($id)
};

declare
  %rest:path('/jobs/{$id}/unregister') 
function _:unregister-job($id) {
  jobs:stop($id, map { 'service': true() })
};


declare
  %rest:GET
  %rest:path("/jobs/{$id}")
function _:job-info($id as xs:string) {
    jobs:list-details($id)
};

declare
  %rest:GET
  %rest:path("/jobs/{$id}/finished")
function _:job-finished($id as xs:string) {
    jobs:finished($id)
};

declare
  %rest:GET
  %rest:path("/jobs/{$id}/result")
function _:job-result($id as xs:string) {
    jobs:result($id)
};

declare
  %rest:GET
  %rest:path("/jobs")
function _:jobs() {
    jobs:list()
};

declare
  %rest:GET
  %rest:path("/jobs/services")
function _:services() {
    jobs:services()
};