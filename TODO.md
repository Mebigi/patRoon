# Release

## general
- test negative subset indices
- convertMSFiles()
    - Agilent .d is also a directory?

## docs
- improve instructions for MF and SIRIUS installation?
- mention potential conflicts with dplyr::filter()


## sets
- fGroups: provide methods for non-implemented functionality
- find nice way to re-use docs
- filter() for features/fGroups: support ionized masses for mass filters? or just clarify it doesn't.
- handle/test empty objects
- more descriptive messages what's going on with all the avaraging of MSPeakLists
- --> does it make sense to keep neutralized MS(/MS) peaklists? radicals are a problem here. Perhaps just force sets specifier when accessing peaklists (unless all adducts are equal)?
- annotatedPeakList: force sets specifier and always use ionized peaklists?
- don't neutralize fragInfo for formulas/compounds?
- maybe keep neutralization for annotation objects but clearly document they may not always make sense and should be used with care. In any case, it shouldn't be used with e.g. reporting in patRoon


## features
- feature optim:
    - docs
        - mention parameters default unless specified
    - keep retcor_done?
    - get rid of getXCMSSet() calls?
- suspect screening
    - rename patRoonData::targets?
    - rename groupFeaturesScreening?
- filter()
    - document which filters work on feature level (e.g. chromWidth)
    - remove zero values for maxReplicateIntRSD?
- importFeaturesXCMS/importFeaturesXCMS3/importFeatureGroupsXCMS: get rid of anaInfo arg requirement? (or make import func?)
- comparison(): support xcms3? (needs missing support for missing raw data)

## MSPeakLists
- isotope tagging is lost after averaging
- collapse averagedPeakLists
- test avg params
- metadata() generic?


## compounds
- SIRIUS: use --auto-charge instead of manually fixing charge of fragments (or not? conflicting docs on what it does)
- test score normalization?
- timeouts for SIRIUS?
- do something about negative H explained fragments by MF?
- PubChemLite
    - Install from Win inst script --> now only tier1, OK?
- SusDat MF support


## formulas
- customize/document ranking column order? (only do rank for sirius?)
- getFormInfoList(): take care of consensus results like getPrecursorFormScores()

## components
- RC: check spearmans correlation
- NT: minimum size argument, combine rows for multiple rGroups?


## reporting
- add more options to reportPlots argument of reportHTML()?


## Cleanup
- Reduce non-exported class only methods


# Future

## General

- msPurity integration
- suspect screening: add MS/MS qualifiers
- newProject(): generate Rmd?
- fillPeaks for CAMERA (and RAMClustR?)
- support fastcluster for compounds clustering/int component clusters?
- algorithmObject() generic: for xset, xsa, rc, ...
- newProject(): fix multi line delete (when possible)
- more withr wrapping? (dev, par)
- improve default plotting for plotInt and cluster plot functions
- newProject(): concentration column for anaInfo


## Features

- integrate OpenMS feature scoring and isotopes and PPS in general (also include filters?)
- parallel enviPick
- OpenMS MetaboliteAdductDecharger support?
- OpenMS: Support KD grouper?
- suspect screening: tag fGroups with suspect instead of converting fGroups object (and add filter to remove non-hits)
- Integration of mzMine features (package pending...), MS-DIAL and KPIC2, peakonly, SIRIUS?


## MSPeakLists

- DA
    - generateMSPeakListsDA: find precursor masses with larger window
    - tests
        - utils? EICs with export/vdiffr?
        - test MS peak lists deisotoping?
- metadata for Bruker peaklists?


## Formulas

- DBE calculation for SIRIUS?
- OM reporting
- as.data.table: option to average per replicate group?


## Compounds

- do something with sirius fingerprints? --> comparison?
- fix compoundViewer
- add new MF HD scorings and make sure default normalization equals that of MF web
- CFM-ID and MS-FINDER integration
- Update SIRIUS interface for 4.4


## components
- mass defect components
- CliqueMS
- split peak correlation and adduct etc annotation? would allow better non-target integration


## Reporting
- report spectra/tables?

## TPs
- Suspects --> BT --> MF DB/suspect list (opt combine with precursors)
