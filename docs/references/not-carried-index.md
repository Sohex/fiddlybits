# Rows of the old references index not carried

Source: `/home/cfutro/docs/world/references/INDEX.md` at commit
6aa93489d233d4e9d531d6479d338c643e34bc5e, 1282 lines, read in full. The parser found
443 distinct table rows: 420 paper or data rows, 19 source-tree rows, and 4 rows of a
silcrete-type table that are not references. Of the 420 paper rows, 284 carry into
`INDEX.md` (86 read, 198 held) and 136 do not. Four papers the old project never held
are listed in `INDEX.md` as `requested`. Of the 19 code trees, 5 carry and 14 do not; the
ECOSTRESS library and the POSEIDON database, which were data holdings outside the
tree table, carry as two further comparison rows.

A row is not carried when it anchors nothing in Parts A to C of the plan for a
generic builder: it documented an internal, a constant or a defect of ExoPlaSim,
LPJ-GUESS, cGENIE or Orogen without the underlying science carrying; it held a
specific configuration's numbers; it was superseded by a scheme the plan names; or the
old row itself recorded it as a negative result. The groups below are the old file's
sections; counts are the not-carried rows in each.

## Papers, by old section

- Fire and natural ignition (14): the BLAZE survival-curve citations (Dalziel 2009, van
  Nieuwstadt 2005, Bond 2008, Cook 2005, Kobziar 2006, Hickler 2004), the McArthur
  spread equations (Noble 1980, Sirakoff 1985), Liedloff 2007, Arora 2005, Knorr 2014
  and 2016, Pellegrini 2018 are fits and constants of a specific fork's fire module;
  B7 names SPITFIRE, whose paper carries. Mahowald 2008 carries once under its other
  filename.
- Volcanic soils, allophane and cation exchange (11): Dahlgren 2004, Parfitt 1983,
  1989, 1990, 2009, Singleton 1989, Sahrawat 1983, Solly 2020, Helling 1964, Manrique
  1991 and Duerr 2011 ground an andisol and cation-exchange sub-model that B8 does not
  scope; the two glass-dissolution papers from the same section carry.
- Trace-gas band models (9): Dickinson 1972, Cess 1972 and 1973, Edwards 1964 and
  1965, Ramanathan 1976, Donner 1980, HITRAN-1973 and Myhre 1998 are the band-model
  machinery a broadband scheme needed; B2 generates absorption line-by-line from
  current HITRAN, so only the forcing checks and the continuum papers carry.
- BVOC, SOA and aerosol coupling (9): isoprene, monoterpene, SOA and biogenic
  nucleation papers describe a process outside the B2 tracer set (dust, sea salt,
  water, ozone); the entry point if an oracle ever fails for its absence.
- Bodele Depression exemplar (8): the deflation, low-level jet, source-area and
  Amazon-fertilisation papers, and the two Vitousek tropical nutrient papers, are one
  Earth locality's story; the P-speciation table and Chadwick 1999 carry.
- Evaporation over dry ground (6): the complementary-relationship papers (Brutsaert
  1979, Morton 1983 a and b, Han 2020, Crago 2021, de Andrade 2025) are offline
  estimators; B4 computes evaporation in the column and B5 makes the carve a process.
- Duricrusts, pavement and silcrete (6 + 4 + 3): calcrete, gypsum-crust stage, desert
  pavement and silcrete papers ground derived surface classes B8 does not name; Watson
  1983 (gypsum window) and Fenske 2025 (water-table process) carry. The three silcrete
  archaeology papers have no anchor.
- cGENIE and PLASIM-GENIE (5): Holden 2016, Edwards 2005, Ridgwell 2007, Naidoo-Bagwell
  2024 and Colbourn 2013 document that host's coupling, tuning and silicon cycle; B3 is
  a new ocean. Ward 2018, Capirala 2026 and Liu 2024 carry as B3 and tier-3 material.
- LPJ-GUESS demography and forcing (5 + 5 + 4): Fulton 1991, Smith 2001, Pacala 1993,
  Smith 2014, Hickler 2012, Richardson 1981, Gerten 2004, Hempel 2013, Lange 2019, and
  the LPJ-GUESS-HYD, RE and ParFlow papers (Papastefanou 2024, Meyer 2025, Verbruggen
  2025, Jia 2026) are that model's formulation, calibration and forcing pipeline; A4
  intervals and A5 ownership make the forcing lessons unrepresentable rather than
  reference-worthy. Sitch 2003 carries once as the comparison DGVM.
- Aeolian phosphorus and loess (5): the acid-processing bioavailability trio (Nenes
  2011, Stockdale 2016, Herbert 2018) and the loess papers (Bettis 2003, Muhs 2013) are
  refinements below B8's stated dust scope.
- Lacis-Hansen and its scoring (4 + 1): Lacis 1974, Yamamoto 1962, Howard 1956 a and b,
  and Freidenreich 1999 are the internals of a two-band scheme B2 replaces.
- CCM3 diagnostic cloud water (4): Kiehl 1996 and 1998, Lloyd 2018 and Stephens 1984
  serve a diagnostic cloud scheme; B2 clouds are prognostic. Covert 2022 and Stephens
  1978 carry as a PDF-width bracket and an optics identity.
- Dust supply and roughness (4 + 2): Macpherson 2008, Kocurek 1999, Laurent 2008 and
  Callot 2000 (no measured roughness, DOI unconfirmed) add nothing the carried
  emission and roughness rows do not; the duplicate Kok 2014 and Marticorena 1995
  filenames are noted on the carried rows.
- C-N-P constants provenance (4): Friend 1997 and Parton 2010 only settle a fork's
  mis-citation; Goll 2012 was acquired and unused; Prentice 1993 hardcodes Earth
  orbital elements that A4 derives from the System.
- Fresh regolith texture (3), lithium and boron rivers (2), lake-solver comparators
  (2): each old row records a search that came up empty or data that cannot serve the
  test (Bockheim 1980, Harden 1987, Chadwick 2003; Huh 1998, Gaillardet 2014; Yapiyev
  2017, Wurtsbaugh 2017). Recorded here so the searches are not repeated.
- Aerosol optics (3): Deschutter 2022 is a recorded dead end; Bond 2006 and Dubovik
  2002 are carbonaceous aerosol optics for a tracer B2 does not carry.
- Surface albedo (3): Cosnefroy 1996 is top-of-atmosphere reflectance; Cohen 2024 and
  Steinrueck 2021 concern a specific haze module and hot-Jupiter hazes.
- Volcanic sulfur (2): Carn 2017 and Andres 1998 feed a sulfate aerosol B2 does not
  carry; Textor 2006 carries as the AeroCom oracle.
- Plant physiology (2), wetlands (2), soil decomposition (1), weathering (1),
  pedology (1), photosynthesis (0): Haxeltine 1996 (a light-use scheme B4 replaces
  with Farquhar at the column step), Hidaka 2013, Kallingal 2024 (an LPJ-GUESS
  calibration), Hoskins 1975 (spectral semi-implicit, rejected by A9), Dunne 1978 (a
  river-chemistry exponent the kinetic route does not use), Mishra 1985 (a mis-fetched
  paper the old row marked not wanted).
- Not-held prose entries: Goody 1964, Selby 1980, Berner 1994, Peters 1984, Noack 2017,
  Cakmur 2004 and the Hunt and Salisbury Modern Geology series are not requested;
  each is either covered by a carried secondary or grounds a route the plan does not
  take. Madras and Sokal 1988, Schmidt and Montgomery 1995, Zhuang 2023 and Lobell and
  Asner 2002 are the four `requested` rows.

## Source trees not carried (14)

BIG-MITgcm, SPEEDY, MARBL, ExoRT, Isca, muffingen, CaMa-Flood, CAABA/MECCA, ESMF, PySDM,
pyrcel, CloudMicrophysics.jl, FATES and ArcSDM were acquired against rows of the old
project's audits (cGENIE grid generation, ExoPlaSim radiation cost, conservative
regridding that A1 makes unnecessary, blind-spot probes). None is named by the plan as
comparison material. Three are worth naming for the import-review pass under A8 rather
than here: pyrcel and CloudMicrophysics.jl as reference implementations of
Abdul-Razzak-Ghan activation for B2, and CAABA/MECCA as the one tree that computes a
methane lifetime for the B7 bracket. ExoRT's four band configurations are a cost ladder
a B2 g-point sweep could be compared against; that is an oracle decision, not a tree to
hold.

## Files on disk with no index row

The predecessor's `references/pdf/` held PDFs that never got an index row (underscore-named `paperfetch` outputs). A sweep of every requested paper against filenames by surname-year and title words found two real holdings, now carried as `held` (Fan et al. 2007; Price and Rind 1992), and one mis-fetched file: `yang2013.pdf` is a Spanish-language education paper, not the Yang, Cowan and Abbot 2013 cloud-feedback letter, so that letter stays requested. Everything else the sweep flagged was a coincidence of words.
