# Release

## general
- test negative subset indices
- convertMSFiles()
    - Agilent .d is also a directory?

## docs
- improve instructions for MF and SIRIUS installation?
- mention potential conflicts with dplyr::filter()
- improve docs for areas (only affects when features=FALSE) and average (different behavior when features=TRUE/FALSE) for as.data.table() of featureGroups
- update/check version nr mentioned in filter() for MSPeakLists


## sets
- provide methods for non-implemented functionality (eg consensus)
- find nice way to re-use docs
- filter() for features/fGroups: support ionized masses for mass filters? or just clarify it doesn't.
- handle/test empty objects
- more descriptive messages what's going on with all the avaraging of MSPeakLists
- remove sets argument for some methods (as.data.table, accessors etc)?
    - if keep, be consistent with all classes
- as.data.table() for formulas: average=T will now produce strange averaged ionized formula, for now simply remove this column.. also give a note in docs? or maybe only remove is not all adducts are equal?
- different name/generic for ionize()? makes less sense for annotation classes
- test DA algorithms
- check if more has to be cached (eg merged results from sets)
- compoundsSetMF sub-class (for settings slot)? or is access via setObjects sufficient? may need to explain anyway for other cases like intclust components
- base set class
    - don't use for fGroupsSet?
- components
    - neutralize masses? otherwise document
        - yay: consistent with other set classes
        - nay: might be a bit strange when looking for adducts etc and components are per set anyway
    - intclust: return componentsSet? if not document somewhere...
    - clearly mention that nontarget is done per set now
    - nontarget-set: plotGraph method?
- implement XCMS conversion functions? maybe with given set. Could just ionize() it.
- ionize() for compounds/components? if not remove formulas?


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
- drop support for reAverage of [ method? doesn't seem so useful, even less so with sets


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
- intclust
    - optionally take areas instead of intensities
    - cache results


## Reporting
- report spectra/tables?

## TPs
- Suspects --> BT --> MF DB/suspect list (opt combine with precursors)
