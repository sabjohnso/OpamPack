#!/bin/bash
# Initialization

readonly opampack_script=$0
readonly ocaml_version=$1; shift
readonly ocaml_packages=$@;


rm -rf _build
mkdir -p _build/opampack
cd _build/opampack



# Get the list of packages from the command-line

OPAM_PACK=$opampack_script
USER_PACKAGES=$ocaml_packages
if [[ -z $USER_PACKAGES ]] ; then
    echo "Error: $OPAM_PACK [PACKAGE] ..."
    exit -1
fi

set -e # IN what follows, fail when an error is encountered

# Download OPAM

#   Download the OPAM installer

wget https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh



# Download the binary of the latest version of OPAM

sh install.sh --download-only
mv opam-* opam
chmod +x opam
rm install.sh

# Create a custom repository with the minimal amount of packages

#   Clone the original repository locally

git clone https://github.com/ocaml/opam-repository.git --depth=1



# Create an empty directory that will contain the opam files

mkdir opamroot



# Set it as the default OPAM root directory

export OPAMROOT=$PWD/opamroot



# Initialize it as an Opam repository, without creating a switch to
# prevent the installation of an OCaml compiler.

echo n \
    | ./opam init \
             --bare \
             --disable-sandboxing \
             --disable-shell-hook \
             --root=$PWD/opamroot \
             $PWD/opam-repository
eval $(./opam env)



# Create an empty switch named =opampack=

./opam switch create --empty --root=$OPAMROOT $ocaml_version
eval $(./opam env --root=$OPAMROOT --switch=$ocaml_version)



# Find the complete list of necessary packages

PACKAGES=$(echo n \
               | ./opam install --dry-run $USER_PACKAGES \
               | awk '/install/ { print $3 }' \
        )
echo "============(BEGIN PACKAGES )======================="
echo $PACKAGES
echo "============(END PACKAGES   )======================="

# In the repository, keep only the required packages:

cd opam-repository
mv packages packages_old
mkdir packages
for p in $PACKAGES ; do
  mv packages_old/$p packages
done



# Remove unnecessary packages and git files

rm -rf packages_old
rm -rf .git
cd ..

# Create the dummy directory

#   Re-create an empty directory that will contain the opam files

rm -rf opamroot
mkdir opamroot



# Set it as the default OPAM root directory

export OPAMROOT=$PWD/opamroot



# Initialize it as an Opam repository, without creating a switch to
# prevent the installation of an OCaml compiler.

echo n \
    | ./opam init \
             --bare \
             --disable-sandboxing \
             --disable-shell-hook \
             --root=$PWD/opamroot \
             $PWD/opam-repository
eval $(./opam env --root=$PWD/opamroot)



# Create an empty switch named =opampack=

./opam switch create --empty $ocaml_version
eval $(./opam env --switch=$ocaml_version)



# Download all the required packages for the installation
echo
echo "============(running opam install for download)======================="
echo
./opam install -y --root=$PWD/opamroot --download-only $USER_PACKAGES



# Create a script to extract the =tar.gz= file and to install the packages.

INSTALL_SCRIPT=install.sh

cat << EOF > $INSTALL_SCRIPT
#!/bin/bash
export OPAMROOT=\$PWD/opamroot
eval \$(./opam env --root=\$PWD/opamroot --switch=$ocaml_version)
./opam install -y --assume-depexts --root=\$PWD/opamroot $USER_PACKAGES
EOF
chmod +x $INSTALL_SCRIPT



# Make a =tar.gz= of all the needed files for exporting OPAM

cd ..  # back in _build
tar -zcvf opampack.tar.gz opampack
rm -rf opampack
