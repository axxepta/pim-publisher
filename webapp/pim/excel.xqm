xquery version "3.0";

module namespace _= "pim/excel";
import module namespace xslt =  "http://basex.org/modules/xslt";

declare variable $_:CAT := db:open('Category');
declare variable $_:PROD := db:open('ProductInfo');
declare variable $_:PROD-ERP := db:open('ProductInfo.ERP');
declare variable $_:FEAT := db:open('Common', 'Feature.xml');

declare variable $_:IMG := db:open('Image');

declare variable $_:IMPORT_FOLDER := 'upload/import/excel';
declare variable $_:IMPORT_PATH := file:resolve-path($_:IMPORT_FOLDER);

declare variable $_:IMPORT_FOLDER_ERP := 'upload/import/excel/schnittstelle';
declare variable $_:IMPORT_PATH_ERP := file:resolve-path($_:IMPORT_FOLDER_ERP);

declare variable $_:IMPORT_FOLDER_ERP_LOCAL := 'upload/import/tmp';
declare variable $_:IMPORT_PATH_ERP_LOCAL := file:resolve-path($_:IMPORT_FOLDER_ERP_LOCAL);

declare variable $_:IMPORT_TMP_FOLDER := 'upload/import/xml';
declare variable $_:IMPORT_TMP_PATH := file:resolve-path($_:IMPORT_TMP_FOLDER);

declare variable $_:XSL := 'process/02_Datenmigration/xsl/';
declare variable $_:XSL-PATH := file:resolve-path($_:XSL);

declare variable $_:EXCEL-EXT := ".xlsx";
declare variable $_:XML-EXT := ".xml";


declare
  %rest:GET
  %rest:path("/pim/excel/convert")
function _:convert-from-folder() {
  
   for $file in file:list($_:IMPORT_PATH_ERP_LOCAL, false(), "*" || $_:EXCEL-EXT)
       
       let $ic := _:import-convert($file)
        
       let $it := ($ic, _:import-transform($file))
        
       (: let $ip := ($it, _:import-process-erp($file)) :)
       
       return $file || ", "
};


declare function _:import-convert($file as xs:string) {

    let $is-erp := contains($file, 'export_schema')
    let $path := if($is-erp) then  $_:IMPORT_PATH_ERP_LOCAL else $_:IMPORT_PATH
    let $conv := "tools/ConvertExcel2Xml.exe"
    
    let $proc := proc:system($conv, ("-f", $path, "-s", "Sheet1", "-p", $file, "-s", "true"))
    
    return $proc
};


declare function _:import-transform($file as xs:string) {

  let $xml-file := replace($file, "\"||$_:EXCEL-EXT, $_:XML-EXT)
  let $xml-pzn-file := replace($file, "\"||$_:EXCEL-EXT, '_pzn' || $_:XML-EXT)
  (: let $path := $_:IMPORT_PATH || $xml-file :)
  let $is-erp := contains($file, 'export_schema')
  let $path := if($is-erp) then  $_:IMPORT_PATH_ERP_LOCAL || $xml-file else $_:IMPORT_PATH || $xml-file
  
  let $doc := doc($path)
  
  let $xsl1 := doc($_:XSL-PATH || "15_openxml2table.xsl")
  let $xsl2 := doc($_:XSL-PATH || "20_buildStructure.xsl")
  let $xsl3 := doc($_:XSL-PATH || "21a_addImages.xsl")
  let $xsl4 := doc($_:XSL-PATH || "30_treadPullRemoveAttributes.xsl")
  
  let $xml1 := xslt:transform($doc, $xsl1) 
  let $xml2 := xslt:transform($xml1, $xsl2) 
  (:let $xml3 := xslt:transform($xml2, $xsl3):) 
  let $xml4 := $xml2 (: xslt:transform($xml3, $xsl4) :)
  
  (: TODO: check import file for errors :)
  let $td := $xml4//td[@type]
  let $out-file := "__"|| $xml-file
  let $out-path := $_:IMPORT_TMP_PATH || $out-file
  
  return if(empty($td))
  then
(:   let $write := file:write($out-path, $xml4, map { "method": "xml"}):)
   let $xml4-no-pzn := <Publication>{(
    $xml4/Publication/@*,
    for $section in $xml4/Publication/Section
    return <Section>{(
        $section/Title,
        $section/ProductInfo[empty(ProductItem/Feature[@Key="PZN"])]
    )}</Section>
   )}</Publication>
   
   let $write-no-pzn := file:write($out-path, $xml4-no-pzn, map { "method": "xml"})
   let $xml4-pzn := <Publication>{(
    $xml4/Publication/@*,
    for $section in $xml4/Publication/Section
    return <Section>{(
        $section/Title,
        $section/ProductInfo[ProductItem/Feature/@Key="PZN"]
    )}</Section>
   )}</Publication>
   let $write-pzn := file:write($_:IMPORT_TMP_PATH || "__"|| $xml-pzn-file, $xml4-pzn, map { "method": "xml"})
   (: let $test := error(xs:QName('err:xsl'), 'could not process') :)
   return "Converted: " || $out-file
   
  else
   let $write := file:write($out-path, <Publication pgDepth="0"/>, map { "method": "xml"})
   return "Error! Unknown properties: " || string-join(distinct-values($td/@type), ", ")
};