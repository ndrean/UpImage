CREATE EXTENSION IF NOT EXISTS citext;
CREATE TABLE "users" (
    "id" bigserial,
    "email" bytea NOT NULL,
    "hashed_email" bytea NOT NULL,
    "username" varchar(255) NOT NULL,
    "name" varchar(255),
    "provider" varchar(255),
    "confirmed_at" timestamp(0),
    "inserted_at" timestamp(0) NOT NULL,
    "updated_at" timestamp(0) NOT NULL,
    PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "users_hashed_email_index" ON "users" ("hashed_email");
CREATE TABLE "urls" (
    "id" bigserial,
    "origin_url" varchar(255),
    "resized_url" varchar(255),
    "thumb_url" varchar(255),
    "key" varchar(255),
    "uuid" uuid,
    "ext" varchar(255),
    "user_id" bigint NOT NULL,
    CONSTRAINT "urls_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
    "inserted_at" timestamp(0) NOT NULL,
    "updated_at" timestamp(0) NOT NULL,
    PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "thumb_url_user_index" ON "urls" ("thumb_url", "user_id")