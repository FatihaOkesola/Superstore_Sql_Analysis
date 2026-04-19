# Superstore SQL Analysis — "What Excel Couldn't Tell Me"

## Overview

This project is the fourth in a series of analyses using the Superstore dataset across multiple tools. While the Excel project answered _where_ revenue comes from, it hit a limitation: pivot tables could calculate aggregates but not reliably compute distinct order-level metrics such as true average order value per region.

This SQL project picks up where Excel left off — using structured querying to go deeper into order-level behavior, shipping efficiency, and customer profitability.

---

## The Starting Point

The Excel project established that West leads in total regional sales (~$725K), followed by East (~$679K), Central (~$501K), and South (~$392K).

The key limitation in Excel was the inability to reliably compute order-level metrics such as average order value using distinct orders. This led to a deeper question:

**Does the region with the highest total sales also generate the highest value per transaction?**

That question drives this entire project.

---

## Database Structure

The flat CSV was normalized into a relational database with four tables:

- **Customer** — customer profile and geography
- **Product** — category, sub-category, and product name
- **Orders** — order and shipping details, linked to Customer
- **Order_Items** — transaction-level sales, profit, quantity, and discount, linked to Orders and Product

A staging table was used to load the raw CSV before inserting clean, deduplicated data into each table.

---

## Key Analysis Areas

**Order Value Analysis** compared average order value across regions using distinct order aggregation — something Excel pivot tables could not calculate cleanly. This revealed that West leads in total sales while East leads in average order value, prompting further investigation into what drives the difference.

**Hypothesis Testing** examined two possible explanations: product mix (H1) and customer segment distribution (H2). Product mix partially explains the difference, as East places fewer but higher-value Technology orders, but this effect is not strong enough to fully account for the regional gap. Customer segment distribution does not explain it — West leads in order share across all segments. The primary driver is transaction-level behavior, not structural composition.

**Shipping Analysis** measured average fulfillment time across ship modes and regions. Shipping time averages approximately 4 days and is consistent across all regions, with differences explained by shipping mode mix rather than operational inefficiency. No region shows a meaningful fulfillment disadvantage.

**Customer Analysis** ranked customers by both sales and profit, revealing that high revenue does not guarantee profitability. Discounting was identified as the key differentiator — Sean Miller generates the highest sales but a negative profit margin (-7.91%) due to a 0.74 average discount, while Tamara Chand achieves a 47.14% margin with disciplined pricing.

---

## Key Findings

- Revenue performance differs across regions, with West being volume-driven and East being value-driven
- Product mix and customer segment do not fully explain regional differences
- Shipping performance is consistent across regions and does not drive variation
- High sales alone is not a reliable indicator of business value
- Discounting is confirmed as a key driver of margin erosion at the customer level.
  This is consistent with findings from the Python profitability diagnostic at the regional and product level.
- Regional performance differences are ultimately driven by transaction-level behavior rather than structural or operational factors

---

## Tools Used

PostgreSQL, pgAdmin, SQL (aggregations, joins, subqueries, window functions, date arithmetic)

---

## How to Run

1. Create a PostgreSQL database in pgAdmin
2. Run the full SQL script to create tables and load data
3. Import `superstore.csv` into the staging table using pgAdmin's Import/Export tool
4. Run the analysis queries in sequence

---

## Dataset

[Superstore Sales Dataset — Kaggle](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)

---

## Part of a Broader Portfolio

This project is the fourth in a series applying different tools to the same dataset:

- Python → Profitability diagnostic and scenario analysis
- Streamlit → Interactive dashboard for non-technical users
- Excel → Sales storytelling with pivot tables and slicers
- SQL → Structured business querying and deeper investigation (this project)

Each tool answered a different business question. The SQL project specifically addresses what flat-file analysis could not.

---

## Author

Fatiha Okesola
