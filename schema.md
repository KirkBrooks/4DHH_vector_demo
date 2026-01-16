# Electronics Product Schema

This document describes the schema for product objects in `meta_Electronics_copy.json` and `meta_Electronics_copy.jsonl`.

## Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `main_category` | string \| null | Top-level product category (e.g., "All Electronics", "Computers") |
| `title` | string | Product name/title |
| `average_rating` | number | Average customer rating (e.g., 3.5, 5.0) |
| `rating_number` | number | Number of ratings received |
| `features` | string[] | List of product features (can be empty) |
| `description` | string[] | Product description paragraphs (can be empty) |
| `price` | number \| null | Price in USD (nullable) |
| `images` | Image[] | Array of product images |
| `videos` | Video[] | Array of product videos (can be empty) |
| `store` | string | Store/brand name |
| `categories` | string[] | Category hierarchy breadcrumb |
| `details` | object | Flexible key-value pairs (varies by product) |
| `parent_asin` | string | Amazon parent ASIN identifier |
| `bought_together` | null | Always null in this dataset |

## Nested Objects

### Image

| Field | Type | Description |
|-------|------|-------------|
| `thumb` | string | Thumbnail image URL |
| `large` | string | Large image URL |
| `variant` | string | Image variant type (e.g., "MAIN", "PT01", "PT02") |
| `hi_res` | string \| null | High-resolution image URL (nullable) |

### Video

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Video title |
| `url` | string | Video URL |
| `user_id` | string | User/influencer ID (can be empty string) |

## Details Field

The `details` object contains product-specific metadata with varying keys. Common fields include:

- `Date First Available` - Product listing date
- `Manufacturer` - Product manufacturer
- `Brand` / `Brand Name` - Product brand
- `Product Dimensions` - Physical dimensions
- `Item Weight` - Product weight
- `Item model number` - Model number
- `Is Discontinued By Manufacturer` - Discontinuation status
- `Color` - Product color
- `Material` - Product material
- `Country of Origin` - Manufacturing country
- `Best Sellers Rank` - Object with category rankings (e.g., `{"Electronics": 317736}`)
- `Part Number` - Manufacturer part number

Additional fields vary by product type (e.g., `Light Source Type`, `Magnification Maximum`, `Compatible Devices`).
