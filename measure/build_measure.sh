#!/bin/bash
# file: build_measure.sh
# info: builds a docker measurement image
IMAGE_REGISTRY=${IMAGE_REGISTRY:-"matt-registry:4000"}
IMAGE_REPO=${IMAGE_REPO:-"s3p/measure"}
IMAGE_TAG=${IMAGE_TAG:-"v0.1"}

if [ -n "$1" ] ; then
    # use arg as image tag if supplied
    IMAGE_TAG="$1"
fi
IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"

DOCKERFILE=${DOCKERFILE:-"measure.Dockerfile"}

echo "Building $IMAGE_NAME from Dockerfile=$DOCKERFILE at $(date) ... "
docker build -t ${IMAGE_NAME} -f ${DOCKERFILE} \
    --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy .

if [ $? = 0 ] ; then
    echo
    echo "Docker image $IMAGE_NAME built successfully:"
    docker images $IMAGE_NAME
    echo -e "\nTo quickly test it, you can launch it with:"
    echo -e "\tdocker run -it --rm --env http_proxy=$http_proxy --env https_proxy=$https_proxy --env no_proxy=$no_proxy $IMAGE_NAME bash"

    if [ -n "$IMAGE_REGISTRY" ] ; then
        echo
        read -p "Would you like to push the image \"$IMAGE_NAME\" to the registry? [y/N] " input
        if [ "${input}" == "y" ]; then
            docker push $IMAGE_NAME
        fi
    fi
else
    echo "An error occurred during the build of $IMAGE_NAME"
fi

