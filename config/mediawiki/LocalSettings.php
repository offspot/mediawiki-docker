<?php
# This file was automatically generated by the MediaWiki 1.20.2
# installer. If you make manual changes, please keep track in case you
# need to recreate them later.
#
# See includes/DefaultSettings.php for all configurable settings
# and their default values, but don't forget to make changes in _this_
# file, not there.
#
# Further documentation for configuration settings may be found at:
# http://www.mediawiki.org/wiki/Manual:Configuration_settings

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

## UPO means: this is also a user preference option
# Debug
#error_reporting( -1 );
#ini_set( 'display_errors', 1 );
#$wgShowExceptionDetails=true;
#$wgShowDBErrorBacktrace = true;
#$wgDebugToolbar=true;
#$wgShowDebug=true;
#$wgDevelopmentWarnings=true;

#$wgDefaultUserOptions['numberheadings'] = false;

# Emails
$wgEnableEmail      = true;
$wgEnableUserEmail  = true; # UPO

$wgEnotifUserTalk      = true; # UPO
$wgEnotifWatchlist     = true; # UPO
$wgEmailAuthentication = true;

## Database settings
#$wgDBtype           = "mysql";
#$wgDBserver         = "localhost";

# MySQL specific settings
#$wgDBprefix         = "";

# MySQL table options to use during installation or update
#$wgDBTableOptions   = "ENGINE=InnoDB, DEFAULT CHARSET=binary";

# Experimental charset support for MySQL 5.0.
#$wgDBmysql5 = false;

## To enable image uploads, make sure the 'images' directory
## is writable, then set this to true:
$wgEnableUploads  = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";
$wgImageMagickIdentifyCommand= "/usr/bin/identify";

# Upload from URL
$wgGroupPermissions['autoconfirmed']['upload_by_url'] = true;
$wgAllowCopyUploads = true;
$wgCopyUploadsFromSpecialUpload = true;
$wgAsyncHTTPTimeout = 120;
$wgHTTPTimeout = 120;

# InstantCommons allows wiki to use images from http://commons.wikimedia.org
$wgUseInstantCommons  = false;

## If you use ImageMagick (or any other shell command) on a
## Linux server, this will need to be set to the name of an
## available UTF-8 locale
$wgShellLocale = "en_US.utf8";

## If you want to use image uploads under safe mode,
## create the directories images/archive, images/thumb and
## images/temp, and make them all writable. Then uncomment
## this, if it's not already uncommented:
#$wgHashedUploadDirectory = false;

## Default skin: you can change the default skin. Use the internal symbolic
## names, ie 'standard', 'nostalgia', 'cologneblue', 'monobook', 'vector':
wfLoadSkin( 'Vector' );
$wgDefaultSkin = "vector";

# Path to the GNU diff3 utility. Used for conflict resolution.
$wgDiff = "/usr/bin/diff";
$wgDiff3 = "/usr/bin/diff3";

# Query string length limit for ResourceLoader. You should only set this if
# your web server has a query string length limit (then set it to that limit),
# or if you have suhosin.get.max_value_length set in php.ini (then set it to
# that value)
$wgResourceLoaderMaxQueryLength = -1;


# Enabled Extensions. Most extensions are enabled by including the base extension file here
# but check specific extension documentation for more details
# The following extensions were automatically enabled:
wfLoadExtension('ConfirmEdit');
wfLoadExtension('Gadgets');
wfLoadExtension('Nuke');
wfLoadExtension('ParserFunctions');
wfLoadExtension('Renameuser');

wfLoadExtension( 'ArticleCreationWorkflow' );

wfLoadExtension('WikiEditor');
$wgDefaultUserOptions['usebetatoolbar'] = 1;

# CategoryTree extension
wfLoadExtension('CategoryTree');

# Cite extension
wfLoadExtension('Cite');

# Titlekey extension allows case-insensitive suggestions
wfLoadExtension('TitleKey');

# InputBox extension
wfLoadExtension('InputBox');

# To allow pictures image map
wfLoadExtension('ImageMap');

# Title blacklist
wfLoadExtension('TitleBlacklist');

# Interwiki extension
wfLoadExtension('Interwiki');
$wgGroupPermissions['sysop']['interwiki'] = true;

# Code highlighting
wfLoadExtension('SyntaxHighlight_GeSHi');

# WikiEditor customization
$wgDefaultUserOptions['usebetatoolbar'] = 1;
$wgDefaultUserOptions['usebetatoolbar-cgd'] = 1;
$wgDefaultUserOptions['wikieditor-preview'] = 1;
#$wgDefaultUserOptions['wikieditor-publish'] = 1;

# CodeEditor (WikiEditor imp.) to edit Lua code
wfLoadExtension( 'CodeEditor' );

# ParserFunctions customization
$wgPFEnableStringFunctions = true;

# Description metatag
wfLoadExtension('MetaDescriptionTag');

# PdfHandler extension
wfLoadExtension('PdfHandler');
$wgPdfProcessor="/usr/bin/gs";
$wgPdfPostProcessor="/usr/bin/convert";
$wgPdfInfo="/usr/bin/pdfinfo";

# TemplateStyles (required for use with Lua module bundling CSS)
wfLoadExtension( 'TemplateStyles' );
$wgTemplateStylesAllowedUrls = [
    'audio' => [ '<.>' ],
    'image' => [ '<.>' ],
    'svg' => [ '<.>' ],
    'font' => [ '<.>' ],
    'namespace' => [ '<.>' ],
    'css' => [ '<.>' ],
];

# Scribunto (Lua) extension
wfLoadExtension( 'Scribunto' );
$wgScribuntoUseGeSHi = true;
$wgScribuntoUseCodeEditor = true;
$wgScribuntoGatherFunctionStats = true;  // ori, 29-Oct-2015
$wgScribuntoSlowFunctionThreshold = 0.99;
$wgScribuntoDefaultEngine = 'luastandalone';
$wgScribuntoEngineConf['luastandalone']['luaPath'] = "/usr/bin/lua5.1";
$wgScribuntoEngineConf['luastandalone']['cpuLimit'] = 30000;
$wgScribuntoEngineConf['luastandalone']['memoryLimit'] = 209715200; # bytes

# UploadWizard extension
wfLoadExtension('UploadWizard');
$wgEnableAPI = true;
$wgEnableWriteAPI = true;
$wgApiFrameOptions = 'SAMEORIGIN'; // Needed to make UploadWizard work in IE, see bug 39877
$wgUploadWizardConfig['altUploadForm'] = 'Special:Upload';
$wgUploadWizardConfig['tutorial']['skip'] = false;
$wgUploadWizardConfig['uwLanguages'] = [ 'en' => 'English' ];
$wgUploadWizardConfig['allCategoriesLink'] = '';
$wgUploadWizardConfig['alternativeUploadToolsPage'] = '';
$wgUploadWizardConfig['wikibase']['enabled'] = false;

$wgExtensionFunctions[] = function() {
    $GLOBALS['wgUploadNavigationUrl'] = SpecialPage::getTitleFor( 'UploadWizard' )->getLocalURL();
    return true;
};

# Hieroglyphs
wfLoadExtension( 'wikihiero' );

# Maths
wfLoadExtension('Math');
$wgMathValidModes = array( 'png' );
$wgDefaultUserOptions['math'] = 'png';

# Timeline
putenv("GDFONTPATH=/usr/share/fonts/truetype/freefont");
wfLoadExtension( 'timeline' );
$wgTimelineFontFile = "FreeSans.ttf";

# Echo extension
wfLoadExtension( 'Echo' );

# Mobile frontend
wfLoadExtension( 'MobileFrontend' );
$wgMFAutodetectMobileView = true;
wfLoadSkin( 'Vector' );
$wgMFDefaultSkinClass = "SkinVector";

wfLoadExtension( 'TextExtracts' );

// # EventLogging used by GuidedTour (depends on EventStreamConfig)
// wfLoadExtension( 'EventStreamConfig' );
// wfLoadExtension( 'EventLogging' );
// # Allow to provides a framework for creating "guided tours,"
// wfLoadExtension( 'GuidedTour' );

# Thanks
wfLoadExtension( 'Thanks' );

# Geo
wfLoadExtension( 'GeoData' );

# Visual Editor
wfLoadExtension( 'VisualEditor' );
$wgVisualEditorAvailableNamespaces = [
    "Project" => true
];

wfLoadExtension( 'TimedMediaHandler' );
wfLoadExtension( 'Widgets' );

wfLoadExtension( 'Iframe' );
$wgIframe = array();


wfLoadExtension( 'Thanks' );

# Mantle extensions
#require_once("$IP/extensions/Mantle/Mantle.php");

# Validator
#require_once("$IP/extensions/Validator/Validator.php");

# Maps
#require_once("$IP/extensions/Maps/Maps.php");

$wgFileExtensions = array_merge( $wgFileExtensions, array( 'doc', 'docx' ) );

# Wikibase
$wgEnableWikibaseRepo = false;
$wgDefaultUserOptions['wlshowwikibase'] = 0;
$wgUploadWizardConfig['wikibase']['enabled'] = false;
#$wgEnableWikibaseClient = true; 
#require_once "$IP/extensions/Wikibase/repo/Wikibase.php";
#require_once "$IP/extensions/Wikibase/repo/ExampleSettings.php"; 
#require_once "$IP/extensions/Wikibase/client/WikibaseClient.php";
#require_once "$IP/extensions/Wikibase/client/ExampleSettings.php";

# Add specific path
function add_include_path ($path) {
    foreach (func_get_args() AS $path) {
        if (!file_exists($path) OR (file_exists($path) && filetype($path) !== 'dir')) {
            trigger_error("Include path '{$path}' not exists", E_USER_WARNING);
            continue;
        }

        $paths = explode(PATH_SEPARATOR, get_include_path());

        if (array_search($path, $paths) === false)
            array_push($paths, $path);

        set_include_path(implode(PATH_SEPARATOR, $paths));
    }
}
add_include_path("/usr/share");
#add_include_path("/usr/share/php");
#add_include_path("/usr/share/php5");

# Urls
$wgScriptPath = "/w";
$wgScriptExtension = ".php";
$wgArticlePath = "/wiki/$1";
$wgStylePath = "$wgScriptPath/skins";

## For attaching licensing metadata to pages, and displaying an
## appropriate copyright notice / icon. GNU Free Documentation
## License and Creative Commons licenses are supported so far.
$wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright
$wgRightsUrl  = "http://creativecommons.org/licenses/by-sa/3.0/";
$wgRightsText = "Creative Commons Attribution Share Alike";
$wgRightsIcon = "/cc-by-sa.png";

# Robots policies
$wgDefaultRobotPolicy = 'noindex,nofollow';
$wgNamespaceRobotPolicies = array( NS_MAIN => 'index,follow' );

# Show "add new section" tab for talk pages
$showNewSection = true;

# Disable logging in by blocked users
$wgBlockDisablesLogin = true;

# rsvg
$wgSVGConverters = array( 'rsvg' => '/usr/bin/rsvg-convert -w $width -h $height -o $output $input');
$wgSVGConverter = 'rsvg' ;

$wgFileExtensions = array_merge( $wgFileExtensions, array( 'tiff', 'tif', 'mp3', 'ogg', 'oga', 'pdf', 'ppt', 'svg', 'dov', 'ott', 'ods', 'odt', 'xlsx', 'xls', 'webm', 'djvu' ) );
$wgDefaultUserOptions['imagesize'] = 4;

# Jobs
$wgJobRunRate = 0.1;
$wgRunJobsAsync = true;

# Uploads
ini_set('memory_limit', '512M');
ini_set('post_max_size', '100M');
ini_set('upload_max_filesize', '100M');
$wgMaxUploadSize = 1024*1024*100;

# Caching
$wgMainCacheType = CACHE_MEMCACHED;
$wgParserCacheType = CACHE_MEMCACHED;
$wgMessageCacheType = CACHE_MEMCACHED;
$wgSessionCacheType = CACHE_MEMCACHED;
$wgSessionsInObjectCache = true;
$wgMemCachedServers = array("127.0.0.1:11211");

$wgUseGzip = true;

# Cache user interface
$wgCacheDirectory = "/dev/shm/mw";
$wgEnableSidebarCache = true;
$wgUseLocalMessageCache = true;

# Admin emails
$wgEmergencyContact = "";
$wgPasswordSender   = "";

# Limit account creation to 2 per IP
$wgAccountCreationThrottle = 99;
$wgGroupPermissions['sysop']['noratelimit'] = true;

# Local interwiki prefix of this wiki
$wgLocalInterwiki = strtolower($wgSitename);

# Licensing
$wgEnableCreativeCommonsRdf = true;

# Tidy HTML code
$wgUseTidy = true;

# When you make changes to this configuration file, this will make
# sure that cached pages are cleared.
$wgCacheEpoch = max( $wgCacheEpoch, gmdate( 'YmdHis', @filemtime( __FILE__ ) ) );

# No visits count
$wgDisableCounters = true;

# Enable subpages in all namespaces
$wgNamespacesWithSubpages = array_fill(0, 200, true);

# Enables AJAX support. Required by some extensions and optional features.
$wgUseAjax = true;
$wgVectorUseIconWatch = true;

# Enable watch star tab
$wgAjaxWatch = true;

# System limitations
$wgMaxShellMemory = 1024000;
$wgMaxShellTime = 3600;
$wgMaxShellFileSize = 524288;

# Number of seconds before autoblock entries expire
$wgAutoblockExpiry = 8640000; 

# Allow user customizations
$wgAllowUserCss = true;
$wgAllowUserJs = true;


# Wikipedia namespace
define("NS_FOO", 3000);
define("NS_FOO_TALK", 3001);
$wgExtraNamespaces[NS_FOO] = "Wikipedia";
$wgExtraNamespaces[NS_FOO_TALK] = "Wikipedia_talk"; // Note underscores in the namespace name.

# Not limit for attempting to login
$wgPasswordAttemptThrottle = false;

# Allow to put __NOINDEX__ on all pages
$wgExemptFromUserRobotsControl = array();

# Allow JS for users
$wgUseSiteJs = true;
$wgUserSiteJs = true;
$wgAllowUserJs = true;

# Allow heavy template
$wgMaxArticleSize = 10000;
$wgExpensiveParserFunctionLimit = 10000;
$wgAllowSlowParserFunctions = true;

# Necessary if you use nginx as reverse proxy
$wgUsePrivateIPs = true;
$wgSquidServersNoPurge = array("127.0.0.1", "192.168.0.0/16");

# Avoid blocked users to login
$wgBlockDisablesLogin = true;

# The following permissions were set based on your choice in the installer
$wgGroupPermissions['*']['createaccount'] = true;
$wgGroupPermissions['*']['edit'] = false;

# Upload file allowed extension
$wgFileExtensions = array_merge( $wgFileExtensions, array( 'zip', 'ogg', 'webm' ) );

// Additional extensions used on WPEN
wfLoadExtension( 'VipsScaler' );
$wgVipsCommand          = "/usr/bin/vips";

wfLoadExtension( 'PagedTiffHandler' );
$wgTiffUseExiv          = true;
$wgExiv2Command         = "/usr/bin/exiv2";
$wgTiffUseTiffinfo      = true;
$wgTiffTiffinfoCommand  = "/usr/bin/tiffinfo";

wfLoadExtension( 'UniversalLanguageSelector' );
wfLoadExtension( 'CiteThisPage' );
// wfLoadExtension( 'ContentTranslation' ); // requires a cx server
wfLoadExtension( 'TemplateSandbox' );
wfLoadExtension( 'PageAssessments' );
wfLoadExtension( 'CodeMirror' );
wfLoadExtension( 'CharInsert' );
wfLoadExtension( 'Kartographer' );
wfLoadExtension( 'LabeledSectionTransclusion' );
wfLoadExtension( 'Poem' );
// wfLoadExtension( 'Score' );  // require shell box and several bins and MEM
// $wgScoreTrim            = true;
// $wgScoreLilyPond        = "/usr/bin/lilypond";

wfLoadExtension( 'TemplateData' );
$wgTemplateDataUseGUI = true;
wfLoadExtension( 'TemplateWizard' );
$wgTemplateDataSuggestedValuesEditor = true;

wfLoadExtension( 'GettingStarted' );
wfLoadExtension( 'PageImages' );
wfLoadExtension( 'AdvancedSearch' );
wfLoadExtension( 'Disambiguator' );
wfLoadExtension( 'Linter' );
wfLoadExtension( 'DismissableSiteNotice' );
wfLoadExtension( 'FileExporter' );
wfLoadExtension( 'JsonConfig' );


// Safety: before extension.json, these values were initialized by JsonConfig.php
if ( !isset( $wgJsonConfigModels ) ) {
    $wgJsonConfigModels = [];
}
if ( !isset( $wgJsonConfigs ) ) {
    $wgJsonConfigs = [];
}

$wgJsonConfigEnableLuaSupport = true;


wfLoadExtension( 'MultimediaViewer' );
wfLoadExtension( 'PageViewInfo' );
wfLoadExtension( 'SandboxLink' );
wfLoadExtension( 'TemplateWizard' );
wfLoadExtension( 'WikiLove' );
// $wgReadingListsMaxEntriesPerList = 5000;
// wfLoadExtension( 'ReadingLists' );
// wfLoadExtension( 'RevisionSlider' );


# Include the cutom part of the configuration
require_once("$IP/LocalSettings.custom.php");

