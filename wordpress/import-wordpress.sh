sed 's/http:\/\/vdupain\.files\.wordpress\.com/https:\/\/vdupain\.files\.wordpress\.com/g' vince039sblog.wordpress.2015-03-10.xml > wordpress.xml

ruby -rubygems -e 'require "jekyll-import";
    JekyllImport::Importers::WordpressDotCom.run({
      "source" => "wordpress.xml",
      "no_fetch_images" => false,
      "assets_folder" => "assets"
    })'
