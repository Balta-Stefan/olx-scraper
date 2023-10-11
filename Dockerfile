# Define custom function directory
ARG FUNCTION_DIR="/scraper"
ARG BROWSER_DRIVER_VERSION="117.0.5938.149"

FROM python:3.10 as build-image

# Include global arg in this stage of the build
ARG FUNCTION_DIR
ARG BROWSER_DRIVER_VERSION

WORKDIR ${FUNCTION_DIR}

# Copy function code
RUN apt update && apt install -y wget unzip \
    && mkdir -p ${FUNCTION_DIR} && cd ${FUNCTION_DIR} \
    && wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/${BROWSER_DRIVER_VERSION}/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && rm chromedriver-linux64.zip \
    && mv chromedriver-linux64/chromedriver chromedriver \
    && rm -r chromedriver-linux64

COPY requirements.txt .
COPY aws_utils.py .
COPY gmail_utils.py .
COPY main.py .

# Install the function's dependencies
RUN pip install -r requirements.txt \
    && pip install --target ${FUNCTION_DIR} awslambdaric

# Use a slim version of the base Python image to reduce the final image size
FROM python:3.10-slim

ARG BROWSER_DRIVER_VERSION
ENV DRIVER_PATH=${FUNCTION_DIR}/chromedriver

# Include global arg in this stage of the build
ARG FUNCTION_DIR
# Set working directory to function root directory
WORKDIR ${FUNCTION_DIR}

RUN apt update && apt upgrade -y && apt install -y chromium=${BROWSER_DRIVER_VERSION}-1~deb12u1

# Copy in the built dependencies
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

# Set runtime interface client as default command for the container runtime
ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
# Pass the name of the function handler as an argument to the runtime
CMD [ "main" ]