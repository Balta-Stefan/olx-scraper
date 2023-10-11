# Use a slim version of the base Python image to reduce the final image size
FROM python:3.10-slim
# Define custom function directory
ARG FUNCTION_DIR="/scraper"
ARG BROWSER_DRIVER_VERSION="117.0.5938.149"
ENV DRIVER_PATH=${FUNCTION_DIR}/chromedriver
ENV BROWSER_PATH=/usr/bin/chromium

WORKDIR ${FUNCTION_DIR}

# Copy function code
RUN apt update && apt upgrade -y \
    && apt install -y wget unzip chromium=${BROWSER_DRIVER_VERSION}-1~deb12u1 \
    && mkdir -p ${FUNCTION_DIR} && cd ${FUNCTION_DIR} \
    && wget https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/${BROWSER_DRIVER_VERSION}/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && rm chromedriver-linux64.zip \
    && mv chromedriver-linux64/chromedriver chromedriver \
    && rm -r chromedriver-linux64 \
    && apt remove -y wget unzip \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Install the function's dependencies
RUN pip install --target ${FUNCTION_DIR} -r requirements.txt \
    && pip install --target ${FUNCTION_DIR} awslambdaric

COPY aws_utils.py .
COPY gmail_utils.py .
COPY main.py .

# Set runtime interface client as default command for the container runtime
ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
# Pass the name of the function handler as an argument to the runtime
CMD [ "main.lambda_handler" ]