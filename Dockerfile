# Psi4 Build Container
# - **Why?** -- So far, our research group has been having a very difficult time building Psi4. Each person's computer
# has a different issue, and its difficult to reproduce things. So, this Docker container was written to provide a
# *standard* environment for building Psi4. The idea is to first build this container, then use the container to build
# Psi4. I know that Conda can make a venv, but this wasn't working properly for some team members. I personally was
# having issues with cmake in builds, and for some reason I'm not having them in docker. At any rate, this is the first
# way I was able to get this to build. This build process is loosely based on the Azure build process, which you cannot
# run on your local system because Microsoft removed that functionality. So, this is a Dockerized version of that, which
# you can use as a base for local reproducible builds, or easy local development. Interestingly, the Azure builds
# include steps that are *not* in the official build docs. I have included what seems to be essential to run the build.
# - **How?** - Run `docker build -t psi4-build .` to build the build image. In other words, this file will JUST build a
# reproducible environment for development. Then, you can use a volume to include the code from your local workspace and
# build without issues and without polluting your local machine with weird versions of packages.
# Once you have the build image built, you can run `docker run -v ./:/home/ubuntu/build/ -it psi4-build /bin/bash` in
# the directory of your (possibly modified) Psi4 code to access a bash shell with the Conda virtual env enabled.
# There's also a useful build script called build.sh that builds and configures from scratch called
# complete-configure-and-build.sh

FROM amd64/ubuntu:20.04

# Add a user with a user group and home dir and bash prompt with ID 1000 and name ubuntu
# This will be our non-root user for the build process
RUN useradd -Um -s /bin/bash -u 1000 ubuntu

# Set up the home dir
WORKDIR /home/ubuntu/
COPY --chown=ubuntu:ubuntu . /home/ubuntu/build/
RUN chown ubuntu:ubuntu /home/ubuntu/build/

# Install build deps
# CAVEAT: This is *technically* non-reproducible since upstream packages can change. I don't know an easy way around this
# Though, I think the effect is limited since we're using an older version of Ubuntu (fewer updates)
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt upgrade -y && apt install -y build-essential cmake make gfortran gcc-10 g++-10 python3 python3-pip wget curl && rm -rf /var/lib/apt/lists/*

# Switch into non-root mode
USER ubuntu

# Install miniconda for Python 3.8
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py38_23.11.0-2-Linux-x86_64.sh -O miniconda.sh && chmod +x miniconda.sh && ./miniconda.sh -b

# Set up the path and install conda deps
ENV PATH=/home/ubuntu/miniconda3/bin:$PATH
RUN conda config --set always_yes yes && conda config --set solver libmamba && conda install pyyaml -c conda-forge

# Now, install Psi4 deps to the conda venv
#WORKDIR /home/ubuntu/build/
RUN build/conda/psi4-path-advisor.py env --name p4env --python 3.8 --disable compilers addons docs
# I guess these are not necessary? They were in the Azure build, but it seems to build fine without it
# Others in my research group have tried building with conda on their host system and have gotten dependency issues, so
# I thought this might be the magic fix, but turns out Docker has more to do with it...
#RUN sed -i "s;- libint;#- libint;g" env_p4env.yaml && sed -i "s;#- psi4::libint;- psi4::libint=2.8.1;g" env_p4env.yaml
#RUN echo '  - psi4::gcp\n\
#  - psi4::dftd3\n\
#  - einsums=*=mkl*\n\
#  - range-v3\n\
#  - zlib' >> env_p4env.yaml && cat env_p4env.yaml && conda env create -n p4env -f env_p4env.yaml
RUN conda env create -n p4env -f env_p4env.yaml

# https://pythonspeed.com/articles/activate-conda-dockerfile/
SHELL ["conda", "run", "-n", "p4env", "/bin/bash", "-c"]
# Doesn't do anything (except print for debug), but useful to compare to the Azure build
RUN conda info && conda list && echo && python -V && python -c 'import numpy; print("Numpy:", numpy.version.version)'

# Clean up
USER root
RUN rm -rf build/* /var/lib/apt/lists/*
USER ubuntu

# Make it so that the p4env is automatically activated
RUN conda init bash
RUN echo conda activate p4env >> ~/.bashrc

# Switch to the build dir (mount your source code as a volume here) and set the default cmd to bash
WORKDIR /home/ubuntu/build/
CMD /bin/bash

# Below... I ran cmake as part of the build container build process just to test things

# RUN conda/psi4-path-advisor.py cmake --objdir build --insist && cat cache_p4env@build.cmake && cmake -S. -B build

#WORKDIR /home/ubuntu/build/build/
#RUN cmake --build . -j2

# Fail out. This way, I can test the build as many times as I like w/o generating images each time
#RUN exit 1
