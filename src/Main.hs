{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad                  ( forM
                                                , liftM
                                                )
import           Data.List                      ( intersperse )
import           Data.Monoid                    ( (<>) )
import           Hakyll
import           Hakyll.Web.Hamlet
import           Hakyll.Web.Pandoc              ( defaultHakyllReaderOptions
                                                , defaultHakyllWriterOptions
                                                , pandocCompilerWith
                                                )
import           Hakyll.Web.Tags                ( tagCloudFieldWith )
import           Text.Blaze.Html                ( (!)
                                                , toHtml
                                                , toValue
                                                )
import           Text.Blaze.Html.Renderer.String
                                                ( renderHtml )
import qualified Text.Blaze.Html5              as H
import qualified Text.Blaze.Html5.Attributes   as A
import qualified Text.Pandoc.Options           as PO

main :: IO ()
main = hakyll $ do
  match "images/**" $ route idRoute >> compile copyFileCompiler
  match "css/*" $ route idRoute >> compile compressCssCompiler
  match "templates/*.hamlet" $ compile hamlTemplateCompiler

  forM ["impressum.md", "datenschutz.md"] $ \page -> match page $ do
    route $ setExtension "html"
    compile
      $   pandocCompiler
      >>= loadAndApplyTemplate "templates/articlepage.hamlet" defaultContext
      >>= loadAndApplyTemplate "templates/default.hamlet"     defaultContext
      >>= relativizeUrls

  forM ["about.hamlet"] $ \page -> match page $ do
    route $ setExtension "html"
    let ctx = constField "title" "About Jacek Galowicz" <> defaultContext
    compile
      $   hamlCompiler
      >>= loadAndApplyTemplate "templates/default.hamlet" ctx
      >>= relativizeUrls

  tags       <- buildTags "posts/*" (fromCapture "tags/*.html")
  indexPages <- buildPaginateWith grouper "posts/*" makeId

  paginateRules indexPages $ \pageNum pattern -> do
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll pattern
      let
        ctx =
          constField
              "title"
              ("Posts" ++ if pageNum > 1
                then " (Page " ++ show pageNum ++ ")"
                else ""
              )
            <> listField "posts" (teaserCtx tags) (return posts)
            <> styledTagCloud "tagcloud" tags
            <> paginateContext indexPages pageNum
            <> defaultContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/post-list.hamlet" ctx
        >>= loadAndApplyTemplate "templates/default.hamlet"   ctx
        >>= relativizeUrls

  tagsRules tags $ \tag pattern -> do
    let title = "Posts tagged \"" <> tag <> "\""
    route idRoute
    compile $ do
      posts <- recentFirst =<< loadAll pattern
      let ctx =
            constField "title" title
              <> listField "posts" (teaserCtx tags) (return posts)
              <> defaultContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/tag.hamlet"     ctx
        >>= loadAndApplyTemplate "templates/default.hamlet" ctx
        >>= relativizeUrls

  match "posts/*" $ do
    route postRoute
    compile
      $   pandocCompilerWith
            defaultHakyllReaderOptions
            defaultHakyllWriterOptions { PO.writerHTMLMathMethod = PO.MathJax "" }
      >>= saveSnapshot "post_content"
      >>= loadAndApplyTemplate "templates/post.hamlet"    (postCtx tags)
      >>= loadAndApplyTemplate "templates/default.hamlet" (postCtx tags)
      >>= relativizeUrls

  createFeed tags "atom.xml" renderAtom
  createFeed tags "feed.xml" renderRss

--------------------------------------------------------------------------------

createFeed tags fileName feedFunction = create [fileName] $ do
  route idRoute
  compile $ do
    let feedCtx = postCtx tags <> bodyField "description"
    posts <- fmap (take 10) . recentFirst =<< loadAllSnapshots "posts/*"
                                                               "post_content"
    feedFunction feedConfig feedCtx posts

dropIndexHtml :: String -> Context a
dropIndexHtml key = mapContext transform (urlField key)
  where transform = reverse . tail . dropWhile (/= '/') . reverse

postCtx :: Tags -> Context String
postCtx tags =
  dateField "date" "%B %e, %Y"
    <> styledTagsField "tags" tags
    <> dropIndexHtml "url"
    <> defaultContext

styledTagsField :: String -> Tags -> Context a
styledTagsField = tagsFieldWith getTags
                                simpleRenderLink
                                (mconcat . intersperse " ")
 where
  simpleRenderLink :: String -> (Maybe FilePath) -> Maybe H.Html
  simpleRenderLink _ Nothing = Nothing
  simpleRenderLink tag (Just filePath) =
    Just
      $ H.a
      ! A.title (H.stringValue ("All pages tagged '" ++ tag ++ "'."))
      ! A.href (toValue $ toUrl filePath)
      ! A.class_ "bg-sky-600 rounded text-white px-1 font-medium"
      $ toHtml tag

styledTagCloud :: String -> Tags -> Context a
styledTagCloud s = tagCloudFieldWith s
                                     renderLink
                                     (mconcat . intersperse " ")
                                     100.0
                                     100.0
 where
  renderLink
    :: Double -> Double -> String -> String -> Int -> Int -> Int -> String
  renderLink minSize maxSize tag url count countMin countMax =
    renderHtml
      $ H.a
      ! A.title (H.stringValue ("All pages tagged '" <> tag <> "'."))
      ! A.href (toValue url)
      ! A.class_ "bg-sky-600 rounded text-white px-1 font-medium"
      $ H.toHtml tag


teaserCtx :: Tags -> Context String
teaserCtx tags = teaserField "teaser" "post_content" <> postCtx tags

grouper :: (MonadFail m, MonadMetadata m) => [Identifier] -> m [[Identifier]]
grouper = fmap (paginateEvery 10) . sortRecentFirst

makeId :: PageNumber -> Identifier
makeId pageNum = fromFilePath $ "index" ++ pageStr ++ ".html"
  where pageStr = if pageNum == 1 then "" else show pageNum

postRoute :: Routes
postRoute =
  gsubRoute "posts/" (const "")
    `composeRoutes` gsubRoute "[0-9]{4}-[0-9]{2}-[0-9]{2}-" (map replaceChars)
    `composeRoutes` gsubRoute ".[a-z]+$" (const "/index.html")
 where
  replaceChars c | c == '-' || c == '_' = '/'
                 | otherwise            = c

feedConfig :: FeedConfiguration
feedConfig = FeedConfiguration
  { feedTitle       = "Jacek's Blog"
  , feedDescription = "This blog is about programming"
  , feedAuthorName  = "Jacek Galowicz"
  , feedAuthorEmail = "jacek@galowicz.de"
  , feedRoot        = "https://blog.galowicz.de"
  }
