# RepPlusApp

A Shiny app for eliciting, rating, and analysing repertory grids using the [OpenRepGrid](https://docs.openrepgrid.org/) R package.  
Outputs are interoperable with **RepPlus** (`.rgrid` format).

---

## ✨ Features

- Add elements and bipolar constructs interactively  
- Collect ratings for each element–construct pair  
- View live element/construct/rating tables  
- Remove or edit ratings  
- Run grid analysis with `OpenRepGrid` and display a 2D construct biplot  
- Download grids as `.csv` or `.rgrid` (RepPlus-compatible)

---

## 🛠️ Setup

### Prerequisites
1. Install [R](https://cran.r-project.org/)  
2. Install [RStudio Desktop](https://posit.co/download/rstudio-desktop/)  
3. Install [Git](https://git-scm.com/)  

### Clone the repo
In RStudio: **File → New Project → Version Control → Git**.  
Repo URL:
git@github.com:ech08ravo/repplus2025.git

---

## 📦 Install dependencies

Open the **Console** in RStudio and run:

```r
install.packages("pak")
pak::pak(c(
  "shiny","DT","uuid",
  "igraph","psych","pvclust","openxlsx","rmarkdown",
  "ech08ravo/OpenRepGrid"
))

(Optional: use renv::init(); renv::snapshot() to lock exact versions.)

⸻

▶️ Run the app

In RStudio:
shiny::runApp()

🖥️ How the app works
	1.	Elements
	•	Enter a name (e.g., e1, e2, e3) and click Add element.
	•	All elements will list in the sidebar.
	2.	Constructs
	•	Enter a left pole (e.g., black) and a right pole (e.g., white).
	•	Click Add construct.
	•	Constructs appear as left - right.
	3.	Ratings
	•	Select an element and a construct.
	•	Use the slider (1–7) to assign a rating.
	•	Click Add rating.
	•	Ratings are shown in a live table.
	•	To remove a rating: select a row → Remove selected rating.
	4.	Sample data
	•	Click Load Sample Data to instantly add:
	•	Elements: e1, e2, e3
	•	Constructs: left–right, black–white, high–low
	•	Pre-filled ratings
	5.	Analysis
	•	Click Analyze Grid (requires ≥3 elements & ≥3 constructs).
	•	Outputs:
	•	Analysis summary from OpenRepGrid
	•	2D construct biplot (visual map of constructs/elements)
	6.	Downloads
	•	Download as CSV → ratings table
	•	Download as .rgrid → RepPlus-compatible file for further analysis

⸻

📂 File structure
	•	app.R → Shiny app code
	•	README.md → this documentation
	•	renv.lock (optional) → reproducible package versions

⸻

🧑‍💻 Contributing
	1.	Fork the repo
	2.	Make your changes in a new branch
	3.	Submit a Pull Request

⸻

📜 License

Open-source under MIT License.