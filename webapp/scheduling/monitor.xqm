module namespace _ = "scheduling/monitor";

import module namespace Monitor = 'http://axxepta.de/converterservices/utils/Monitor';

declare
  %rest:GET
  %rest:path("/monitor/memory")
function _:log-memory() {
  let $path := file:resolve-path('reports/memoryUsage.csv')
  return Monitor:appendMemoryUsageLog($path)
};