FROM rust:latest
RUN apt-get update && apt-get install -y cmake pkg-config libasound2-dev libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# КРИТИЧНО: копируем файлы из папки на компе внутрь образа
COPY . .
RUN cargo build
CMD ["cargo", "run"]
