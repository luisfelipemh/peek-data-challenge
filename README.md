# Peek Data Challenge

## Deliverables
* **SQL Queries:** Located in `/sql/queries.sql`
* **Dashboard & Visuals:**  https://lookerstudio.google.com/reporting/7de1db01-63af-4afa-a62a-c1f19aa5017e  

---

## Key Findings & Product Ideas

* **Main Trend:** Our revenue is growing, but it depends 100% on new customers. Our retention drops a lot. By M1, retention is below 4%. This means our churn is >96% right after the first purchase. This happens across all countries and channels.
* **The Checkout Leak:** 63% of users add items to the cart, but only 26% complete a purchase.
* **Product Ideas: [More context in Data Studio Dashboard]**
  * **SEM A/B Test for Retention:** Launch a new SEM campaign offering "$20 credit for your next order." Run an A/B test at the campaign level and compare M1 retention using the `utm_campaign`. The goal is to test if pre-selling the second purchase increases repeat purchases and reduces our >95% churn.
  * **Landing Page Test:** Run an organic A/B test with a landing page pop-up saying "Unlock Free Shipping for 3 months by creating an account today." Test if users who create an account through the pop-up have higher retention than guest users. We would also capture emails and run lifecycle campaigns to bring users back if they do not purchase again.
  * **Dynamic Progress Bar:** Add a progress bar in the cart showing how close users are to the $100 free shipping threshold (for example: "Add $15 more to get Free Shipping"). This makes the goal more visible and should push users with carts between $80–$99 to add one more item, increasing AOV.
  * **Guest Checkout:** Add Apple Pay, Google Pay, and guest checkout so users can purchase without creating a full account. This reduces friction at checkout and should improve the final conversion rate from cart to purchase.

---

## Definitions & Assumptions

### Key Definitions
* **Active Customer:** A user with at least 1 completed order in a month (`status = 'Complete'` and `returned_at IS NULL`).
* **New vs. Returning:** A "New" customer made their first-ever purchase in that month. A "Returning" customer made their first purchase in a previous month.
* **Monthly Retention (Task B):** Looks at the monthly revenue mix. It measures how many users from any previous month came back to buy again in the current month.
* **Cohort Retention (Part 2):** Tracks a specific group of users over time. M0 is the month a user buys for the first time (always 100%). M1 to M12 show the % of those exact same users who buy again in the following months. Because our M1 retention is less than 4%, it clearly shows our >96% churn right after the first purchase.
* **Cohort:** Users grouped by the month of their first purchase.

### Task C: 90-Day Churn Limitation
* **Limitation:** Looking at a flat 90-day churn number is not very useful. It is too simple and hides how users actually behave over time.
* **How to fix it:** It is much better to look at cohorts (M0, M1, M2). This is exactly why I created the retention charts in Part 2. Cohorts show us exactly *when* users drop off. A 90-day rule hides the fact that the >96% drop happens immediately at M1.

### Task D: Product Change Impact & Data Studio Logic
* **Assumptions:** The Jan 15 "Free Shipping over $100" feature is not in the data. So, I created a proxy segment to track orders >= $100 vs < $100.
* **Success Metrics:** The primary metric is Average Order Value (AOV) because the goal is to make users spend more per checkout. The secondary metric is the % of orders over $100.
* **Google Data Studio Calculation:** In the SQL, I only exported the raw counts (`orders_over_100` and `total_orders`). Then, I created a calculated field in Data Studio to calculate the % of orders over $100.
* **Why I did this in Data Studio:** I wanted to build a line chart because it is the best way to see trends over time. I also added a 7-day moving average line to remove daily noise and see the true overall AOV trend before and after the experiment launch.
* **Extra Data Needed:** To run a real A/B test, I would need an `experiment_group` column (Control vs Variant) and the `shipping_fee` cost.

### Date Ranges & Queries
* **Date Ranges:** For the AOV experiment, I used a tight 60-day window before and after the launch (`2021-11-16` to `2022-03-16`). This helps us see the real impact and removes seasonal noise.
* **How to Run:** All queries use Standard SQL. You can run them directly in the `bigquery-public-data.thelook_ecommerce` dataset.

---

## Part 2: Analysis & Visualization Method

### 2.1 & 2.3: Retention by Channel and Country
* **Why I calculated retention this way:** Instead of just looking at a simple 90-day churn number, I used a cohort analysis (M0 to M12) (Months).
* Tracking the exact same group of users over time is much more insightful. It shows us exactly *when* they stop buying. The charts show a massive drop immediately at M1, which tells us users are treating us like a one-time shop.

### 2.2: User Journey Funnel
* I built a step-by-step funnel (Site Visit -> Product View -> Add to Cart -> Purchase) using session events.
* This is the best way to spot where the product is failing. It helped me find that we have 63% of people add items to the cart but 26.59% are buyinh

---

## Part 3: AI & Analytics

* **AI Usage:** I used Gemini to write the base SQL queries, structure the CTEs, and check for edge cases.
* **Future Use:** Next time, I would use Cursor to write Python scripts for data pipelines by giving the AI my SQL and table schemas.
* **Prompt Example:** *"Here are my table schemas and 10 sample rows for the orders and users tables. Write a BigQuery SQL query to calculate M1-M12 retention. Sanity check: Retention at M0 must always be 100%. If you see any data gaps, let me know so I can help."*
* **Validation:** I do not trust the AI blindly. I always check the total row counts against the base tables to make sure no data is lost in the joins. I also manually check the final percentages to see if they make sense (like M0 = 100%).
