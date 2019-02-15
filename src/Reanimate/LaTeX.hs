{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}
module Reanimate.LaTeX where

import System.Process
import System.Exit
import System.IO
import System.IO.Unsafe
import System.FilePath
import System.Directory
import Control.Exception
import Lucid (toHtmlRaw, toHtml)
import Lucid.Svg (Svg, text_, font_size_, fill_)
--toHtmlRaw svgFile

--latex -interaction=batchmode -halt-on-error
--dvisvgm {file} -n -v 0 -o out

latex :: String -> Svg ()
latex = unsafePerformIO . latexToSVG

latexToSVG :: String -> IO (Svg ())
latexToSVG tex = handle (\(e::SomeException) -> return (failedSvg tex)) $ do
  latex <- requireExecutable "latex"
  dvisvgm <- requireExecutable "dvisvgm"
  withTempDir $ \tmp_dir -> withTempFile "tex" $ \tex_file -> withTempFile "svg" $ \svg_file -> do
    let dvi_file = tmp_dir </> replaceExtension (takeFileName tex_file) "dvi"
    writeFile tex_file tex_prologue
    appendFile tex_file tex
    appendFile tex_file tex_epilogue
    runCmd latex ["-interaction=batchmode", "-halt-on-error", "-output-directory="++tmp_dir, tex_file]
    runCmd dvisvgm [dvi_file, "-n","-v", "0", "-o",svg_file]
    svg_data <- readFile svg_file
    evaluate (length svg_data)
    return $ toHtmlRaw $ unlines $ drop 1 $ lines svg_data

failedSvg :: String -> Svg ()
failedSvg tex =
  text_ [ font_size_ "20"
        , fill_ "white"] (toHtml $ "bad latex: "++tex)

runCmd exec args = do
  (ret, stdout, stderr) <- readProcessWithExitCode exec args ""
  evaluate (length stdout + length stderr)
  case ret of
    ExitSuccess -> return ()
    ExitFailure err -> do
      putStrLn $
        "Failed to run: " ++ showCommandForUser exec args ++ "\n" ++
        "Error code: " ++ show err ++ "\n" ++
        "stderr: " ++ show stderr
      throwIO (ExitFailure err)

withTempDir action = do
  dir <- getTemporaryDirectory
  (path, handle) <- openTempFile dir "reanimate-XXXXXX"
  hClose handle
  removeFile path
  createDirectory (dir </> path)
  action (dir </> path) `finally` removeDirectoryRecursive (dir </> path)

withTempFile ext action = do
  dir <- getTemporaryDirectory
  (path, handle) <- openTempFile dir ("reanimate-XXXXXX" <.> ext)
  hClose handle
  action path `finally` removeFile path

requireExecutable :: String -> IO FilePath
requireExecutable exec = do
  mbPath <- findExecutable exec
  case mbPath of
    Nothing -> error $ "Couldn't find executable: " ++ exec
    Just path -> return path


tex_prologue =
  "\\documentclass[preview]{standalone}\n\
  \\\usepackage[english]{babel}\n\
  \\\usepackage{amsmath}\n\
  \\\usepackage{amssymb}\n\
  \\\usepackage{dsfont}\n\
  \\\usepackage{setspace}\n\
  \\\usepackage{tipa}\n\
  \\\usepackage{relsize}\n\
  \\\usepackage{textcomp}\n\
  \\\usepackage{mathrsfs}\n\
  \\\usepackage{calligra}\n\
  \\\usepackage{wasysym}\n\
  \\\usepackage{ragged2e}\n\
  \\\usepackage{physics}\n\
  \\\usepackage{xcolor}\n\
  \\\usepackage{textcomp}\n\
  \\\usepackage{microtype}\n\
  \\\DisableLigatures{encoding = *, family = * }\n\
  \%\\usepackage[UTF8]{ctex}\n\
  \\\linespread{1}\n\
  \\\begin{document}\n\
  \\\begin{align*}\n"

tex_epilogue =
  "\n\
  \\\end{align*}\n\
  \\\end{document}"
