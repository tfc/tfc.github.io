{-# LANGUAGE OverloadedStrings #-}
import Control.Monad (liftM)
import           Data.Monoid ((<>))
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
                  constField "title" ("Blog Archive - Page " ++ (show pageNum)) <>
                  listField "posts" (teaserCtx) (return posts) <>
                  paginateCtx <>
                  defaultContext
          makeItem ""
              >>= loadAndApplyTemplate "templates/index.hamlet" ctx
              >>= loadAndApplyTemplate "templates/default.hamlet" ctx
              >>= relativizeUrls

{-
    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let ctx = listField "posts" teaserCtx (return posts) <>
                      defaultContext
            getResourceBody
              >>= applyAsTemplate ctx
              >>= loadAndApplyTemplate "templates/default.hamlet" ctx
              >>= relativizeUrls
              -}

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ pandocCompiler
            >>= saveSnapshot "post_content"
            >>= loadAndApplyTemplate "templates/post.hamlet" postCtx
            >>= loadAndApplyTemplate "templates/default.hamlet" postCtx
            >>= relativizeUrls


--------------------------------------------------------------------------------
postCtx :: Context String
postCtx = dateField "date" "%B %e, %Y" <> defaultContext

teaserCtx :: Context String
teaserCtx = teaserField "teaser" "post_content" <> postCtx

grouper :: MonadMetadata m => [Identifier] -> m [[Identifier]]
grouper = liftM (paginateEvery 10) . sortRecentFirst

makeId :: PageNumber -> Identifier
makeId pageNum = fromFilePath $ "index" ++ pageStr ++ ".html"
    where pageStr = if pageNum == 1 then "" else show pageNum
