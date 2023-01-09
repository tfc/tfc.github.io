{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad                  ( liftM )
import           Data.List                      ( intersperse )
import           Data.Monoid                    ( (<>) )
import           Hakyll
import           Hakyll.Web.Hamlet
import           Text.Blaze.Html                ( (!)
                                                , toHtml
                                                , toValue
                                                )
import qualified Text.Blaze.Html5              as H
import qualified Text.Blaze.Html5.Attributes   as A

main :: IO ()
main = hakyll $ do
  match "images/**" $ do
    route idRoute
    compile copyFileCompiler

  match "css/*" $ do
    route idRoute
    compile compressCssCompiler

  match "templates/*.hamlet" $ compile hamlTemplateCompiler

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
            <> tagCloudField "tagcloud" 100.0 100.0 tags
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
              `mappend` listField "posts" (teaserCtx tags) (return posts)
              `mappend` defaultContext
      makeItem ""
        >>= loadAndApplyTemplate "templates/tag.hamlet"     ctx
        >>= loadAndApplyTemplate "templates/default.hamlet" ctx
        >>= relativizeUrls


  match "posts/*" $ do
    route postRoute
    compile
      $   pandocCompiler
      >>= saveSnapshot "post_content"
      >>= loadAndApplyTemplate "templates/post.hamlet"    (postCtx tags)
      >>= loadAndApplyTemplate "templates/default.hamlet" (postCtx tags)
      >>= relativizeUrls

  match "about.md" $ do
    route $ setExtension "html"
    compile
      $   pandocCompiler
      >>= loadAndApplyTemplate "templates/default.hamlet" defaultContext
      >>= relativizeUrls

  match "impressum.md" $ do
    route $ setExtension "html"
    compile
      $   pandocCompiler
      >>= loadAndApplyTemplate "templates/default.hamlet" defaultContext
      >>= relativizeUrls

  match "datenschutz.md" $ do
    route $ setExtension "html"
    compile
      $   pandocCompiler
      >>= loadAndApplyTemplate "templates/default.hamlet" defaultContext
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
      ! A.class_ "tag-link"
      $ toHtml tag

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
