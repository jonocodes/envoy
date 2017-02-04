
# This script containes helpers/knowledge about the dockerfiles structure and docker compose files

function list_projects {
  echo "$(find $PROJECTS/*/build-image.sh | awk -F/ '{print $(NF-1)}')"
}

function list_stacks {
  echo "$(find $CONFIGURATIONS/*.yml -exec basename -s .yml -a {} +)"
}

# Given a docker-compose file, this will extract all the images referenced in it. Helpful for determining which images need to be built.
function get_images_from_config {
  CONFIG_FILE=$1
  echo $(docker-compose -f $CONFIG_FILE config | grep '^ *image:' | sed 's/.*image: *\([^ ][^ ]*\).*$/\1/')
}
