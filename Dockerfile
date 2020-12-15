FROM --platform=arm64 mcr.microsoft.com/dotnet/sdk:5.0 AS build

# See for all possible platforms
# https://github.com/containerd/containerd/blob/master/platforms/platforms.go#L17

WORKDIR /source

ARG TARGETARCH

# Copy csproj and restore.
COPY src/Impostor.Server/Impostor.Server.csproj ./src/Impostor.Server/Impostor.Server.csproj
COPY src/Electric.AUProximity/Electric.AUProximity.csproj ./src/Electric.AUProximity/Electric.AUProximity.csproj
COPY src/Impostor.Api/Impostor.Api.csproj ./src/Impostor.Api/Impostor.Api.csproj
COPY src/Impostor.Hazel/Impostor.Hazel.csproj ./src/Impostor.Hazel/Impostor.Hazel.csproj

RUN case "$TARGETARCH" in \
    amd64)  NETCORE_PLATFORM='linux-x64';; \
    arm64)  NETCORE_PLATFORM='linux-arm64';; \
    arm)    NETCORE_PLATFORM='linux-arm';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac && \
  dotnet restore -r "$NETCORE_PLATFORM" ./src/Impostor.Server/Impostor.Server.csproj && \
  dotnet restore -r "$NETCORE_PLATFORM" ./src/Electric.AUProximity/Electric.AUProximity.csproj && \
  dotnet restore -r "$NETCORE_PLATFORM" ./src/Impostor.Api/Impostor.Api.csproj && \
  dotnet restore -r "$NETCORE_PLATFORM" ./src/Impostor.Hazel/Impostor.Hazel.csproj

# Copy everything else.
COPY src/. ./src/
RUN case "$TARGETARCH" in \
    amd64)  NETCORE_PLATFORM='linux-x64';; \
    arm64)  NETCORE_PLATFORM='linux-arm64';; \
    arm)    NETCORE_PLATFORM='linux-arm';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac && \
  dotnet publish -c release -o /app -r "$NETCORE_PLATFORM" --no-restore ./src/Impostor.Server/Impostor.Server.csproj && \
  dotnet publish -c release -o /app -r "$NETCORE_PLATFORM" --no-restore ./src/Electric.AUProximity/Electric.AUProximity.csproj

# Final image.
FROM --platform=amd64 mcr.microsoft.com/dotnet/runtime:5.0
WORKDIR /app
COPY --from=build /app ./
COPY --from=build /source/src/Impostor.Server/config.json ./

# Replace PublicIP on Run
ENV PUBLICIP=127.0.0.1
RUN sed -i -r "s/Replace with your external facing IP/${PUBLICIP}/g" ./config.json 

EXPOSE 22023/udp
ENTRYPOINT ["./Impostor.Server"]