SRC_HC_OPTS               = -O -H64m
GhcStage1HcOpts           = -O
GhcStage2HcOpts           = -O2
GhcLibHcOpts              = -O2
BUILD_PROF_LIBS           = YES
DYNAMIC_TOO               = NO
DYNAMIC_GHC_PROGRAMS      = NO
SplitObjs                 = NO
SplitSections             = NO
BUILD_SPHINX_HTML         = YES
BUILD_SPHINX_PDF          = NO
HADDOCK_DOCS              = YES
EXTRA_HADDOCK_OPTS        += --quickjump --hyperlinked-source
