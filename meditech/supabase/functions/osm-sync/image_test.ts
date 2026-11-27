import { assertEquals } from "jsr:@std/assert";
import { pickImageUrlFromOsmTags } from "./image_url.ts";

Deno.test("pickImageUrlFromOsmTags uses image tag", () => {
  const url = pickImageUrlFromOsmTags({
    image: "https://example.com/pharmacy.jpg",
  });
  assertEquals(url, "https://example.com/pharmacy.jpg");
});

Deno.test("pickImageUrlFromOsmTags builds Wikimedia Commons URL", () => {
  const url = pickImageUrlFromOsmTags({
    "wikimedia_commons": "File:Iloilo Pharmacy.jpg",
  });
  assertEquals(
    url,
    "https://commons.wikimedia.org/wiki/Special:FilePath/Iloilo%20Pharmacy.jpg?width=512",
  );
});