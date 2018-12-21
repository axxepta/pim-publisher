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

declare
  %updating
  %rest:GET
  %rest:path("/pim/excel/import")
function _:import-from-folder() {
  
   for $file in file:list($_:IMPORT_PATH_ERP_LOCAL, false(), "*" || $_:EXCEL-EXT)
    
    return
      try {
        _:import-process-erp($file)
      } catch * {
         admin:write-log('ERP IMPORT ' || $file || ' FAILED')
      }
       
};

declare %updating
function _:import-images-from-folder() {
  
   for $file in file:list($_:IMPORT_PATH_ERP, false(), "*" || $_:EXCEL-EXT)
        
   return
     try {
        _:import-process-images($file)
         } catch * {
         admin:write-log('ERP IMAGES IMPORT ' || $file || ' FAILED: ' || $err:description || ' in ' || $err:module || ' at ' || $err:line-number)
      }
       
};

declare
  %rest:GET
  %rest:path("/pim/excel/list")
  %output:method("xml")
function _:import-list() {
   
   let $importable := (
   for $file in file:list($_:IMPORT_PATH_ERP, false(), "*" || $_:EXCEL-EXT)
   return <File>{$file}</File>
   ,
    for $file in file:list($_:IMPORT_PATH, false(), "*" || $_:EXCEL-EXT)
   return <File>{$file}</File>
   )
   
   return $importable
};

declare
  %rest:GET
  %rest:path("/pim/excel/edit/{$file}")
  %output:method("xml")
function _:import-edit($file) {
   
  let $is-erp := contains($file, 'export_schema')
  let $path := if($is-erp) then  $_:IMPORT_PATH_ERP || $file else $_:IMPORT_PATH || $file
  
  let $size := file:size($path)
  let $date := file:last-modified($path)
  
  return <File Type="{if($is-erp) then 'ERP' else 'STD'}">
           <Name>{$file}</Name>
           <Path>{$path}</Path>
           <Size>{$size}</Size>
           <Date>{$date}</Date>
        </File>
};

declare
  %rest:GET
  %rest:path("/pim/excel-convert/{$file}")
  %output:method("text")
function _:import-convert($file as xs:string) {

    let $is-erp := contains($file, 'export_schema')
    let $path := if($is-erp) then  $_:IMPORT_PATH_ERP_LOCAL else $_:IMPORT_PATH
    let $conv := "tools/ConvertExcel2Xml.exe"
    
    let $proc := proc:system($conv, ("-f", $path, "-s", "Sheet1", "-p", $file, "-s", "true"))
    
    return $proc
};


declare
  %rest:GET
  %rest:path("/pim/excel-transform/{$file}")
  %output:method("text")
function _:import-transform($file as xs:string) {

  let $xml-file := replace($file, "\"||$_:EXCEL-EXT, $_:XML-EXT)
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
  let $xml3 := xslt:transform($xml2, $xsl3) 
  let $xml4 := $xml3 (: xslt:transform($xml3, $xsl4) :)
  
  (: TODO: check import file for errors :)
  let $td := $xml4//td[@type]
  let $out-file := "__"|| $xml-file
  let $out-path := $_:IMPORT_TMP_PATH || $out-file
  
  return if(empty($td))
  then
   let $write := file:write($out-path, $xml4, map { "method": "xml"})
   (: let $test := error(xs:QName('err:xsl'), 'could not process') :)
   return "Converted: " || $out-file
  else
   let $write := file:write($out-path, <Publication pgDepth="0"/>, map { "method": "xml"})
   return "Error! Unknown properties: " || string-join(distinct-values($td/@type), ", ")
};

declare
  %updating
  %rest:GET
  %rest:path("/pim/excel-process-erp/{$file}")
  %output:method("text")
function _:import-process-erp($file as xs:string) {
  
   let $xml-file := replace($file, "\"||$_:EXCEL-EXT, $_:XML-EXT)
   let $path := $_:IMPORT_TMP_PATH || "__" || $xml-file
   
   return
    for $section in doc($path)/*/Section
       return _:import-section-erp($section)
};


declare
  %updating
  %rest:GET
  %rest:path("/pim/excel-process/{$file}")
  %output:method("text")
function _:import-process($file as xs:string) {

   let $xml-file := replace($file, "\"||$_:EXCEL-EXT, $_:XML-EXT)
   let $path := $_:IMPORT_TMP_PATH || "__" || $xml-file
   
   return(
   for $section in doc($path)/*/Section
   return _:import-section($section)
   ,
    for $f in doc($path)/*//Feature
     let $key := $f/@Key
     group by $key
     return _:import-feature($f[1])
   )
};

declare
  %updating
  %rest:GET
  %rest:path("/pim/excel-images/{$file}")
  %output:method("text")
function _:import-process-images($file as xs:string) {

   let $xml-file := replace($file, "\"||$_:EXCEL-EXT, $_:XML-EXT)
   let $path := $_:IMPORT_TMP_PATH || "__" || $xml-file
   
   return
       for $image-group in doc($path)/*//Image (:[not(@width = '')] :)
         let $src := $image-group/@Source
         group by $src
         return _:import-images($image-group)

};

declare
%updating
function _:import-section($section as element(Section)) {
 
 let $key := string($section/Title)
 let $cat := $_:CAT//Category[@Key = $key]
 
 let $with-products := exists($section/ProductInfo)
 
 return if($with-products) then ( 
   (: _:import-section-erp-update($key, $section) ,  :)
 for $f in $section//Feature
   let $key := $f/@Key
   group by $key
   return _:assign-feature($f[1], $cat)
 ,
 for $p in $section/ProductInfo
 return _:import-product($p, $cat)
 
 )
 
 else _:import-item-updates($section)
};

declare
%updating
function _:import-section-erp($section as element(Section)){

 let $key := string($section/Title)
 return _:replace-section-erp($key, $section)
 
 (:
 let $cat := $_:CAT//Category[@Key = $key][1]
 let $cat-todo := $_:CAT//Category[@Key = '100'][1]
 let $cat-todo-items := $_:CAT//Category[@Key = '101'][1]
 
 
 return if($cat) then ( 
   _:replace-section-erp($key, $section)
   ,
   for $f in $section//Feature
       let $key := $f/@Key
       group by $key
       return _:assign-feature($f[1], $cat)
 )

 )

 else admin:write-log("SECTION WITHOUT CATEGORY IN PIM: " || $key, "ERROR")
   :) 
};

declare
%updating
function _:import-section-erp-update($key, $section as element(Section)){

  let $exists := db:exists("ProductInfo.ERP", $key || ".xml")
  return
  
    if($exists) then 
    (: add or replace single products :)
       let $sec-erp := db:open("ProductInfo.ERP", $key || ".xml")
       
       for $p in $section/ProductInfo
        let $item-ids := $p/ProductItem/SupplierArticleId
        
        (: get erp product by article no. :)
        let $p-erp := $_:PROD-ERP//ProductInfo[ProductItem/SupplierArticleId = $item-ids]
        
        return if(count($p-erp) = 1)
          (: replace part by part :)
          then 
             let $log := admin:write-log("UPDATE ERP ITEM: " || string-join($p-erp/ProductName, ", ") || " WITH " || string-join($p/ProductName, ", "))
             let $data-erp := $p-erp/node() except ($p-erp/ProductItem)
             let $data-p := $p/node() except ($p/ProductItem)
             let $items-merged := 
               for $id in distinct-values(($p-erp/ProductItem/SupplierArticleId, $item-ids))
                 return
                 (: if exists both, old and new PZN article then keep old :)
                 if(($p/ProductItem[SupplierArticleId = $id][Feature/@Key='PZN'][Feature[@Key='Gesperrt']='false']) and ($p-erp/ProductItem[SupplierArticleId = $id])) then $p-erp/ProductItem[SupplierArticleId = $id] 
                 else if($p/ProductItem[SupplierArticleId = $id]) then $p/ProductItem[SupplierArticleId = $id]
                 else $p-erp/ProductItem[SupplierArticleId = $id]
             let $p-merged := 
             <ProductInfo>
              {$p-erp/@*}
              {() (: $data-erp :) }
              {$data-p}
              {$items-merged}
              </ProductInfo>
          return 
              (: if same group as before :)
              if($p-erp/parent::Section/Title = $sec-erp/Section/Title) then
              replace node $p-erp with $p-merged
              (: else into new group, remove old :)
              else (delete node $p-erp, insert node $p-merged into $sec-erp )
          
          else if(count($p-erp) > 1) then (admin:write-log("DUPLICATE: " || string-join($p-erp/ProductName, ", ")), error(xs:QName('err:duplicate'), 'could not import erp product') )
          
          (: insert as new erp product :)
          else insert node $p into $sec-erp
          
    (: replace all :)      
    else _:replace-section-erp($key, $section)
};

declare
%updating
function _:replace-section-erp($key, $section as element(Section)){

 db:replace("ProductInfo.ERP", $key || ".xml", $section)
};

declare
%updating
function _:assign-feature($feat as element(Feature), $cat as element(Category) ){
  
    if($cat/Feature[@Key = $feat/@Key])
      then ()
    else 
      insert node <Feature Key="{$feat/@Key}"/> into $cat
};

declare
%updating
function _:import-feature($feat as element(Feature)){
  
   let $db-feat := $_:FEAT//Feature[@Key = $feat/@Key]
   let $group := if($feat/@readonly) then "ERP" else ""
  
   return 
   if($db-feat) then ()
   else 
    insert node <Feature Key="{$feat/@Key}" Type="{if($feat/@Type) then $feat/@Type else 'String' }" Group="{$group}" UnitGroup="">
                      <Name xml:lang="de">{string($feat/@Key)}</Name>
                </Feature> into $_:FEAT/*
};

declare
%updating
function _:import-images($image-group as element(Image)+) {

  let $src := $image-group[1]/@Source
  
  let $db-img := ($_:IMG//Image[@Source = $src])[1]
  let $db-img-guids := $db-img/Link/@Guid
  
  
  (: let $log := admin:write-log("IMPORT IMAGE " || $src || " (GUIDS: " || string-join($db-img-guids, ', ') || ")" , "INFO") :)
 
 let $image :=
  <Image>
    {$image-group[1]/@*}
     
     {
       for $img in $image-group[parent::ProductItem]
       let $item-no := $img/parent::ProductItem/SupplierArticleId
       let $db-item := $_:PROD//ProductItem[Data/SupplierArticleId = $item-no]
       return <Link To="ProductItem" Guid="{$db-item/@Guid}"/>
     }
     
     {
       for $img in $image-group[parent::ProductInfo]
       let $item-no := $img/parent::ProductInfo/ProductItem/SupplierArticleId         
       let $db-item := $_:PROD//ProductItem[Data/SupplierArticleId = $item-no]
       let $db-product := $db-item/parent::*/parent::ProductInfo
       return <Link To="ProductInfo" Guid="{$db-product/@Guid}"/>
     }
           
  </Image>
  let $new-links := $image/Link except $image/Link[@Guid = $db-img-guids]
  return if($db-img and $new-links) then (insert node $new-links into $db-img, admin:write-log("IMPORT IMAGE LINKS FOR " || $db-img/@Source, "INFO"))
         else if(empty($db-img)) then (insert node $image into $_:IMG/*, admin:write-log("IMPORT NEW IMAGE " || $image/@Source, "INFO"))
         else ()
};

declare
%updating
function _:import-product-erp($product as element(ProductInfo), $category as element(Category), $cat-todo as element(Category), $cat-todo-items as element(Category)) {
 
  let $item-no := $product/ProductItem/SupplierArticleId
  (: get one article that matches :)
  let $db-item := $_:PROD//ProductItem[Data/SupplierArticleId = $item-no]
  (: use parent product of these article(s) :)
  let $db-product := $db-item/parent::*/parent::ProductInfo
  let $db-product-items  := $db-product/ProductItemList/ProductItem
  
  let $at := _:current-dateTime-UTC()
  
  (: create or update :)
  return if(count($db-product) = 1) 
  then 
      let $new-items := 
      for $item in $product/ProductItem
      return if(empty($db-product-items[Data/SupplierArticleId = $item/SupplierArticleId])) then 
      
      <ProductItem Guid="{random:uuid()}" Status="Entw.">
      <Data Was="created" At="{$at}" By="importer">
       <Status>Entw.</Status>
      {$item/Name}
      {$item/SupplierArticleId}
       </Data>
      </ProductItem> 
      
      else ()
      
      return (
         if($product/ProductName = $db-product/Data/ProductName) then () else try { replace value of node $db-product[1]/Data[1]/ProductName with string-join($product/ProductName, "") } catch * { admin:write-log("RENAME DUPLICATE FOR " || $product/ProductName, 'WARNING') }
         ,
         if($new-items) then (
                 admin:write-log("INSERT ITEMS (FROM ERP): " || string-join($new-items/SupplierArticleId, ", ") || " into " || $db-product/Data[1]/ProductName[1])
                 ,
                 insert node $new-items into $db-product[1]/ProductItemList
                 ,
                 if(empty($db-product/Data/Category[@Guid = $cat-todo-items/@Guid])) then insert node <Category Guid="{$cat-todo-items/@Guid}"/> into $db-product/Data else ()
                 ,
                 
                  if(empty($db-product/Data/Category[@Guid = $category/@Guid])) then insert node <Category Guid="{$category/@Guid}"/> into $db-product/Data else ()
                 )
                 else ()
             )

  else if(count($db-product) > 1) then (admin:write-log("DUPLICATE (FROM ERP): " || string-join($db-product/Data/ProductName, ", ")) ) (: , error(xs:QName('err:duplicate'), 'could not import product') ) :)
  
  else 
   let $log := admin:write-log("INSERT NEW (FROM ERP): " || string-join($product/ProductName, ", ") )
   let $new := 
   <ProductInfo Guid="{random:uuid()}" Status="Entw.">
      <Data Was="created" At="{$at}" By="importer">
       <Status>Entw.</Status>
       {$product/ProductName}
       <Category Guid="{$category/@Guid}"/>
       <Category Guid="{$cat-todo/@Guid}"/>
      </Data>
      <ProductItemList>
        {    
        for $item in $product/ProductItem
        return  
        <ProductItem Guid="{random:uuid()}" Status="Entw.">
        <Data Was="created" At="{$at}" By="importer">
         <Status>Entw.</Status>
         {$item/Name}
         {$item/SupplierArticleId}
         </Data>
        </ProductItem> 
        }
      </ProductItemList>

   </ProductInfo> 
   
   return insert node $new into $_:PROD/*

};

declare
%updating
function _:import-item-updates($section as element(Section)){

  for $item in $section/ProductItem
  (: get one article that matches :)
  let $db-item := $_:PROD//ProductItem[Data/SupplierArticleId = $item/SupplierArticleId]
  return if($db-item) then _:update-item-data($db-item, $item) else ()
};


declare
%updating
function _:update-item-data($db-item, $item){
   let $iks := $item/K[not(. = $db-item/Data/K)]
   let $iwks := $item/WK[not(. = $db-item/Data/WK)]
   
   return 
      (
        if($item/Name != $db-item/Data[1]/Name) then replace value of node $db-item[1]/Data[1]/Name with string-join($item/Name, "") else ()
        ,
         if($item/K) then insert node $iks into $db-item[1]/Data[1] else ()
         ,
         if($item/WK) then insert node $iwks into $db-item[1]/Data[1] else ()
        ,
        for $item-feat in $item/Feature[not(@readonly)][@Key != 'Beschreibung' and @Key != 'Technische Daten']
          let $db-item-feat := $db-item/Data/Feature[@Key = $item-feat/@Key]
          return if($db-item-feat) then replace value of node $db-item-feat with $item-feat/node()
          else insert node <Feature>{($item-feat/@Key, $item-feat/@Unit)}{$item-feat/node()}</Feature> into $db-item/Data
        )
  
};

declare
%updating
function _:import-product($product as element(ProductInfo), $category as element(Category)?) {
 
  let $item-no := $product/ProductItem/SupplierArticleId
  (: get one article that matches :)
  let $db-item := $_:PROD//ProductItem[Data/SupplierArticleId = $item-no]
  (: use parent product of these article(s) :)
  let $db-product := $db-item/parent::*/parent::ProductInfo
  
  let $at := _:current-dateTime-UTC()
  
  (: create or update :)
  return if(count($db-product) = 1) 
  then 
   let $db-prod-name := $db-product[1]/Data[1]/ProductName
   let $log := admin:write-log("UPDATE: "||string-join($db-prod-name, ", ") || " WITH " || string-join($product/ProductName, ", ") )
                               (: TODO : should not have multiple db-product here | :)
                               
   let $ks := $product/K[not(. = $db-product/Data/K)]
   let $wks := $product/WK[not(. = $db-product/Data/WK)]
   (: let $log := admin:write-log("WK: "||string-join($wks, ' ')) :)
   
   return (
       (: update name, category and add new articles or features :)
       (: 
       if($product/ProductName != $db-prod-name) then replace value of node $db-product[1]/Data[1]/ProductName with string-join($product/ProductName, "") else ()
       , 
       if($db-product[1]/Data/Category/@Guid != $category/@Guid) then replace node $db-product[1]/Data[1]/Category/@Guid with $category/@Guid else () 
       ,
       :)
       if($product/K) then insert node $ks into $db-product[1]/Data[1] else ()
       ,
       if($product/WK) then insert node $wks into $db-product[1]/Data[1] else ()
       ,
       for $feat in $product/Feature[not(@readonly)][@Key != 'Beschreibung' and @Key != 'Technische Daten']
        let $db-feat := $db-product[1]/Data/Feature[@Key = $feat/@Key]
        return if($db-feat) then replace value of node $db-feat with $feat/node()
                            else insert node <Feature>{($feat/@Key, $feat/@Unit)}{$feat/node()}</Feature> into $db-product[1]/Data
        ,
        for $item in $product/ProductItem
          let $db-item := $db-product[1]/ProductItemList/ProductItem[Data/SupplierArticleId = $item/SupplierArticleId]
    
            return if(count($db-item) > 1) then (admin:write-log("DUPLICATE: " || string-join($item/SupplierArticleId, ", "))) (: , error(xs:QName('err:duplicate'), 'could not import item') ) :)
            else if(count($db-item) = 1) then _:update-item-data($db-item, $item)
            else insert node _:product-item($item) into $db-product[1]/ProductItemList
                             
         )
  else if(count($db-product) > 1) then (admin:write-log("DUPLICATE: " || string-join($db-product/Data/ProductName, ", ")) ) (: , error(xs:QName('err:duplicate'), 'could not import product') ) :)
  
  else 
   let $log := admin:write-log("INSERT NEW: " || string-join($product/ProductName, ", ") )
   let $new :=
   <ProductInfo Guid="{random:uuid()}" Status="Entw.">
      <Data Was="created" At="{$at}" By="importer">
       <Status>Entw.</Status>
       {$product/* except($product/Feature, $product/ProductItem, $product/ProductText, $product/Image, $product/Price)}
       
       {for $feat in $product/Feature[not(@readonly)][@Key != 'Beschreibung' and @Key != 'Technische Daten']
         return <Feature>{($feat/@Key, $feat/@Unit)}{$feat/node()}</Feature>
       }
       
       {if($category) then <Category Guid="{$category/@Guid}"/> else ()}
      </Data>
      <ProductItemList>
        {    
        for $item in $product/ProductItem
        return _:product-item($item)
        }
      </ProductItemList>
       <TextList>
        { _:product-texts($product)}
      </TextList>
   </ProductInfo> 
   
   return insert node $new into $_:PROD/*
   
};

declare function _:product-item($item as element(ProductItem)){
 
   let $at := _:current-dateTime-UTC()
   return
     <ProductItem Guid="{random:uuid()}" Status="Entw.">
      <Data Was="created" At="{$at}" By="importer">
       <Status>Entw.</Status>
       <Name>{$item/Name/text()}</Name>
       {$item/* except($item/Name, $item/Feature, $item/Text, $item/Image, $item/Price)}
       {for $feat in $item/Feature[not(@readonly)][@Key != 'Beschreibung' and @Key != 'Technische Daten']
         return <Feature>{($feat/@Key, $feat/@Unit)}{$feat/node()}</Feature>
       }
       </Data>
       <TextList>
        { _:productitem-texts($item)}
      </TextList>
      </ProductItem> 
};

declare function _:productitem-texts($item as element(ProductItem)){
 
   let $at := _:current-dateTime-UTC()
   let $texts := 
   for $text at $pos in $item/Feature[@Key='Beschreibung' or @Key='Technische Daten'] (: $item/Text :)
   return
   <Text Guid="{random:uuid()}" Key="{string-join($text/@Key | $text/Key, "")}" O="{$pos}">
     <Data Was="created" At="{$at}" By="importer">
       <xhtml>
          {$text/node()}
       </xhtml>
     </Data>
   </Text>
   
  return $texts
};

declare function _:product-texts($item as element(ProductInfo)){

   let $at := _:current-dateTime-UTC()
   let $texts := 
   for $text at $pos in $item/Feature[@Key='Beschreibung' or @Key='Technische Daten'] (: $item/Text :)
   return
   <Text Guid="{random:uuid()}" Key="{string-join($text/@Key | $text/Key, "")}" O="{$pos}">
     <Data Was="created" At="{$at}" By="importer">
       <xhtml>
          {$text/node()}
       </xhtml>
     </Data>
   </Text>
   
  return $texts
};


declare function _:current-dateTime-UTC()
{
    adjust-dateTime-to-timezone(current-dateTime(), xs:dayTimeDuration('PT0H'))
};