{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad (liftM)
import           Data.Monoid   ((<>))
import           Hakyll
import           Hamlet

main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match "templates/*.hamlet" $ compile hamlTemplateCompiler

    indexPages <- buildPaginateWith grouper "posts/*" makeId

    paginateRules indexPages $ \pageNum pattern -> do
      route idRoute
      compile $ do
          posts <- recentFirst =<< loadAll pattern
          let paginateCtx = paginateContext indexPages pageNum
              ctx =
                  constField "title" ("Posts" ++ if (pageNum > 1)
                                then " (Page " ++ (show pageNum) ++ ")"
                                else "") <>
                  listField "posts" (teaserCtx) (return posts) <>
                  paginateCtx <>
                  defaultContext
          makeItem ""
              >>= loadAndApplyTemplate "templates/post-list.hamlet" ctx
              >>= loadAndApplyTemplate "templates/default.hamlet" ctx
              >>= relativizeUrls

    match "posts/*" $ do
        route $ postRoute
        compile $ pandocCompiler
            >>= saveSnapshot "post_content"
            >>= loadAndApplyTemplate "templates/post.hamlet" postCtx
            >>= loadAndApplyTemplate "templates/default.hamlet" postCtx
            >>= relativizeUrls

    match "about.md" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.hamlet" defaultContext
            >>= relativizeUrls


--------------------------------------------------------------------------------
dropIndexHtml :: String -> Context a
dropIndexHtml key = mapContext transform (urlField key) where
    transform = reverse . tail . dropWhile (/= '/') . reverse

postCtx :: Context String
postCtx = dateField "date" "%B %e, %Y" <>
          dropIndexHtml "url" <>
          defaultContext

teaserCtx :: Context String
teaserCtx = teaserField "teaser" "post_content" <> postCtx

grouper :: MonadMetadata m => [Identifier] -> m [[Identifier]]
grouper = liftM (paginateEvery 10) . sortRecentFirst

makeId :: PageNumber -> Identifier
makeId pageNum = fromFilePath $ "index" ++ pageStr ++ ".html"
    where pageStr = if pageNum == 1 then "" else show pageNum

postRoute :: Routes
postRoute =
    gsubRoute "posts/" (const "") `composeRoutes`
    gsubRoute "[0-9]{4}-[0-9]{2}-[0-9]{2}-" (map replaceChars) `composeRoutes`
    gsubRoute ".[a-z]+$" (const "/index.html")
    where
        replaceChars c | c == '-' || c == '_' = '/'
                       | otherwise = c
