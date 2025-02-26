ARG IMAGE
ARG RMBLAST_IMAGE

FROM "${RMBLAST_IMAGE}" as rmblast_builder

FROM "${IMAGE}" as nseg_builder

ARG NSEG_URL
ARG NSEG_PREFIX_ARG
ENV NSEG_PREFIX="${NSEG_PREFIX_ARG}"
ENV PATH="${PATH}:${NSEG_PREFIX}/bin"


WORKDIR "${NSEG_PREFIX}/bin"
RUN  set -eu \
  && DEBIAN_FRONTEND=noninteractive \
  && . /build/base.sh \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       build-essential \
       wget \
  && rm -rf /var/lib/apt/lists/* \
  && wget -r -nd "${NSEG_URL}" \
  && make \
  && chmod a+x runnseg \
  && rm *.c *.h *.o makefile


FROM "${IMAGE}" as repscout_builder

ARG REPEATSCOUT_VERSION
ARG REPEATSCOUT_URL
ARG REPEATSCOUT_PREFIX_ARG
ENV REPEATSCOUT_PREFIX="${REPEATSCOUT_PREFIX_ARG}"

ENV PATH="${PATH}:${REPEATSCOUT_PREFIX}/bin"

WORKDIR "${REPEATSCOUT_PREFIX}"
RUN  set -eu \
  && DEBIAN_FRONTEND=noninteractive \
  && . /build/base.sh \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       build-essential \
       wget \
  && rm -rf /var/lib/apt/lists/* \
  && wget "${REPEATSCOUT_URL}" \
  && tar zxf RepeatScout* \
  && rm RepeatScout*.tar.gz \
  && mv RepeatScout*/ "${REPEATSCOUT_PREFIX}/bin" \
  && cd bin \
  && make \
  && rm *.c *.h *.o *.fa *.freq Makefile notebook README


FROM "${IMAGE}" as recon_builder

ARG RECON_VERSION
ARG RECON_URL
ARG RECON_PREFIX_ARG
ENV RECON_PREFIX="${RECON_PREFIX_ARG}"

ENV PATH="${PATH}:${RECON_PREFIX}/bin:${RECON_PREFIX}/scripts"


WORKDIR "${RECON_PREFIX}"
RUN  set -eu \
  && DEBIAN_FRONTEND=noninteractive \
  && . /build/base.sh \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
       build-essential \
       wget \
  && rm -rf /var/lib/apt/lists/* \
  && wget "${RECON_URL}" \
  && tar zxf RECON* \
  && rm RECON*.tar.gz \
  && mv RECON*/* ./ \
  && rmdir RECON*/ \
  && cd src \
  && make install \
  && cd "${RECON_PREFIX}" \
  && rm -rf -- src Demos \
  && sed -i "s~path = \"\"~path = \"${RECON_PREFIX}/bin\"~" scripts/recon.pl

# WARNING! This setup is not-necessarily robust to changing the RECON_PREFIX!


FROM "${IMAGE}"

ARG TRF_VERSION
ARG TRF_URL
ARG TRF_PREFIX_ARG
ENV TRF_PREFIX="${TRF_PREFIX_ARG}"
ENV PATH="${TRF_PREFIX}/bin:${PATH}"

# Install blast and repeat modeller deps from other images.
ARG RMBLAST_VERSION
ARG RMBLAST_PREFIX_ARG
ENV RMBLAST_PREFIX="${RMBLAST_PREFIX_ARG}"

ENV PATH="${RMBLAST_PREFIX}/bin:${PATH}"
ENV CPATH="${RMBLAST_PREFIX}/include"
ENV LIBRARY_PATH="${RMBLAST_PREFIX}/lib:${LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="${RMBLAST_PREFIX}/lib:${LD_LIBRARY_PATH}"

COPY --from=rmblast_builder "${RMBLAST_PREFIX}" "${RMBLAST_PREFIX}"
COPY --from=rmblast_builder "${APT_REQUIREMENTS_FILE}" /build/apt/rmblast.txt

ARG NSEG_PREFIX_ARG
ENV NSEG_PREFIX="${NSEG_PREFIX_ARG}"
ENV PATH="${NSEG_PREFIX}/bin:${PATH}"

COPY --from=nseg_builder "${NSEG_PREFIX}" "${NSEG_PREFIX}"
COPY --from=nseg_builder "${APT_REQUIREMENTS_FILE}" /build/apt/nseg.txt


ARG REPEATSCOUT_VERSION
ARG REPEATSCOUT_PREFIX_ARG
ENV REPEATSCOUT_PREFIX="${REPEATSCOUT_PREFIX_ARG}"

ENV PATH="${REPEATSCOUT_PREFIX}/bin:${PATH}"

COPY --from=repscout_builder "${REPEATSCOUT_PREFIX}" "${REPEATSCOUT_PREFIX}"
COPY --from=repscout_builder "${APT_REQUIREMENTS_FILE}" /build/apt/repeatscout.txt


ARG RECON_VERSION
ARG RECON_PREFIX_ARG
ENV RECON_PREFIX="${RECON_PREFIX_ARG}"

ENV PATH="${RECON_PREFIX}/bin:${RECON_PREFIX}/scripts:${PATH}"

COPY --from=recon_builder "${RECON_PREFIX}" "${RECON_PREFIX}"
COPY --from=recon_builder "${APT_REQUIREMENTS_FILE}" /build/apt/recon.txt


# Set some working environment variables.
ARG RMASK_VERSION
ARG RMASK_URL
ARG RMASK_PREFIX_ARG
ENV RMASK_PREFIX="${RMASK_PREFIX_ARG}"

ENV RM_LIB="${RMASK_PREFIX}/Libraries"


ARG RMOD_VERSION
ARG RMOD_URL
ARG RMOD_PREFIX_ARG
ENV RMOD_PREFIX="${RMOD_PREFIX_ARG}"

ENV PATH="${RMASK_PREFIX}:${RMASK_PREFIX}/util:${RMOD_PREFIX}:${RMOD_PREFIX}/util:${PATH}"


# Install blast/rm dependencies, download trf, download repmodeler and repmask
WORKDIR /tmp
RUN  set -eu \
  && DEBIAN_FRONTEND=noninteractive \
  && . /build/base.sh \
  && add_runtime_dep \
       hmmer \
       libjson-perl \
       liblapack3 \
       liblwp-useragent-determined-perl \
       libtext-soundex-perl \
       liburi-perl \
       perl \
       wget \
  && cp "${APT_REQUIREMENTS_FILE}" /build/apt/repmask.txt \
  && apt-get update \
  && apt_install_from_file /build/apt/*.txt \
  && rm -rf /var/lib/apt/lists/* \
  && wget "${TRF_URL}" \
  && mkdir -p "${TRF_PREFIX}/bin" \
  && mv trf*.linux64 "${TRF_PREFIX}/bin" \
  && chmod a+x ${TRF_PREFIX}/bin/trf*.linux64 \
  && ln -sf ${TRF_PREFIX}/bin/trf*.linux64 "${TRF_PREFIX}/bin/trf" \
  && wget "${RMASK_URL}" \
  && tar -zxf RepeatMasker*.tar.gz \
  && rm RepeatMasker*.tar.gz \
  && mkdir -p "${RMASK_PREFIX}" \
  && mv RepeatMasker*/* "${RMASK_PREFIX}" \
  && rm -rf -- RepeatMasker* \
  && wget "${RMOD_URL}" \
  && tar -zxf RepeatModeler-*.tar.gz \
  && rm RepeatModeler*.tar.gz \
  && mkdir -p "${RMOD_PREFIX}" \
  && mv RepeatModeler*/* "${RMOD_PREFIX}" \
  && rm -rf -- RepeatModeler*

# Configure repeatmasker scripts
WORKDIR "${RMASK_PREFIX}"
RUN  cp RepeatMaskerConfig.tmpl RepeatMaskerConfig.pm \
  && sed -i "s~TRF_PRGM\s*=\s*\"\"~TRF_PRGM = \"${TRF_PREFIX}/bin/trf\"~" RepeatMaskerConfig.pm \
  && sed -i 's/DEFAULT_SEARCH_ENGINE\s*=\s*"crossmatch"/DEFAULT_SEARCH_ENGINE = "ncbi"/' RepeatMaskerConfig.pm \
  && sed -i 's~HMMER_DIR\s*=\s*"/usr/local/hmmer"~HMMER_DIR = "/usr/bin"~' RepeatMaskerConfig.pm \
  && sed -i "s~RMBLAST_DIR\s*=\s*\"/usr/local/rmblast\"~RMBLAST_DIR = \"${RMBLAST_PREFIX}/bin\"~" RepeatMaskerConfig.pm \
  && sed -i 's~"$REPEATMASKER_DIR/Libraries"~$ENV{"RM_LIB"}~' RepeatMaskerConfig.pm \
  && sed -i 's~REPEATMASKER_DIR/Libraries~REPEATMASKER_LIB_DIR~' RepeatMasker \
  && sed -i '/use strict;$/a use lib $ENV{"RM_LIB"};' RepeatMasker \
  && sed -i '/use strict;$/a use lib $ENV{"RM_LIB"};' ProcessRepeats \
  && sed -i 's~use lib "\$FindBin::RealBin/Libraries";~use lib $ENV{"RMLIB"} . "/Libraries";~' ProcessRepeats \
  && sed -i 's~\$DIRECTORY/Libraries~" . $ENV{"RM_LIB"} . "~g' ProcessRepeats \
  && rm -f Libraries/Dfam.hmm Libraries/Dfam.embl \
  && perl -i -0pe 's/^#\!.*perl.*/#\!\/usr\/bin\/env perl/g' \
       RepeatMasker \
       DateRepeats \
       ProcessRepeats \
       RepeatProteinMask \
       DupMasker \
       util/queryRepeatDatabase.pl \
       util/queryTaxonomyDatabase.pl \
       util/rmOutToGFF3.pl \
       util/rmToUCSCTables.pl


# Configure repeatmodeler scripts
WORKDIR ${RMOD_PREFIX}
RUN  cp RepModelConfig.pm.tmpl RepModelConfig.pm \
  && sed -i "s~REPEATMASKER_DIR\s*=\s*\"/usr/local/RepeatMasker\"~REPEATMASKER_DIR = \"${RMASK_PREFIX}\"~" RepModelConfig.pm \
  && sed -i 's~"$REPEATMASKER_DIR/Libraries/RepeatMasker.lib"~$ENV{"RM_LIB"} . "/RepeatMasker.lib"~' RepModelConfig.pm \
  && sed -i "s~RMBLAST_DIR\s*=\s*\"/usr/local/rmblast\"~RMBLAST_DIR = \"${RMBLAST_PREFIX}/bin\"~" RepModelConfig.pm \
  && sed -i "s~RECON_DIR\s*=\s*\"/usr/local/bin\"~RECON_DIR = \"${RECON_PREFIX}/bin\"~" RepModelConfig.pm \
  && sed -i "s~NSEG_PRGM\s*=\s*\"/usr/local/bin/nseg\"~NSEG_PRGM = \"${NSEG_PREFIX}/nseg\"~" RepModelConfig.pm \
  && sed -i "s~RSCOUT_DIR\s*=\s*\"/usr/local/bin/\"~RSCOUT_DIR = \"${REPEATSCOUT_PREFIX}/bin\"~" RepModelConfig.pm \
  && sed -i "s~TRF_PRGM\s*=\s*\"/usr/local/bin/trf\"~TRF_PRGM = \"${TRF_PREFIX}/bin/trf\"~" RepModelConfig.pm \
  && sed -i 's~"-db $RepModelConfig::REPEATMASKER_DIR/Libraries/RepeatPeps.lib "~"-db " . $ENV{"RM_LIB"} . "/RepeatPeps.lib "~' RepeatClassifier \
  && sed -i 's~"Missing $RepModelConfig::REPEATMASKER_DIR/Libraries/"~"Missing " . $ENV{"RM_LIB"} . "/"~' RepeatClassifier \
  && sed -i 's~"$RepModelConfig::REPEATMASKER_DIR/Libraries~$ENV{"RM_LIB"} . "~' RepeatClassifier \
  && perl -i -0pe 's/^#\!.*/#\!\/usr\/bin\/env perl/g' \
       configure \
       BuildDatabase \
       Refiner \
       RepeatClassifier \
       RepeatModeler \
       TRFMask \
       util/dfamConsensusTool.pl \
       util/renameIds.pl \
       util/viewMSA.pl
