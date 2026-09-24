# ETW2001 A2 - EMEA Pricing Strategy Dashboard
# HOW TO RUN MY SETUP: 
#   1. Run data_prep.R once to create shiny_master_data.csv.
#   2. Open this file in RStudio and click "Run App".


library(shiny)
library(shinydashboard)
library(ggplot2)
library(plotly)
library(dplyr)
library(scales)

#  Load data 
master <- read.csv("shiny_master_data.csv", stringsAsFactors = FALSE,
                   check.names = TRUE)

country_volume <- master %>%
  group_by(Country) %>%
  summarise(n = n(), .groups = "drop") %>%
  filter(n >= 50) %>%
  pull(Country) %>%
  sort()

all_subcats <- sort(unique(master$Sub.Category))

# Helper: lock a plotly chart (no drag/zoom, no toolbar) but keep hover
lock_plot <- function(p) {
  p %>%
    config(displayModeBar = FALSE) %>%
    layout(dragmode = FALSE)
}

#  UI 
ui <- dashboardPage(
  skin = "red",
  dashboardHeader(title = "EMEA Pricing Strategy", titleWidth = 300),

  dashboardSidebar(
    width = 300,
    sidebarMenu(menuItem("Dashboard", tabName = "dash", icon = icon("dashboard"))),
    hr(),
    tags$div(style = "padding: 0 15px;",
      tags$b("Countries (>=50 rows):"),
      tags$div(style = "margin: 5px 0;",
        actionButton("country_all", "Select All", class = "btn-xs"),
        actionButton("country_none", "Clear", class = "btn-xs")
      ),
      checkboxGroupInput("country", NULL,
                         choices = country_volume,
                         selected = country_volume)
    ),
    hr(),
    sliderInput("year", "Year range:",
                min = 2011, max = 2014, value = c(2011, 2014),
                step = 1, sep = ""),
    hr(),
    tags$div(style = "padding: 0 15px;",
      tags$b("Sub-Category:"),
      tags$div(style = "margin: 5px 0;",
        actionButton("subcat_all", "Select All", class = "btn-xs"),
        actionButton("subcat_none", "Clear", class = "btn-xs")
      ),
      checkboxGroupInput("subcat", NULL,
                         choices = all_subcats,
                         selected = all_subcats)
    ),
    hr(),
    selectInput("focus", "Viz 3 focus country (time series):",
                choices = country_volume,
                selected = if ("Turkey" %in% country_volume) "Turkey" else country_volume[1])
  ),

  dashboardBody(
    tabItems(
      tabItem(
        tabName = "dash",
        fluidRow(
          valueBoxOutput("kpi_sales", width = 3),
          valueBoxOutput("kpi_profit", width = 3),
          valueBoxOutput("kpi_margin", width = 3),
          valueBoxOutput("kpi_discount", width = 3)
        ),
        fluidRow(
          box(title = "Viz 1: GDP per Capita vs Avg Discount (debunking the wealth myth)",
              status = "danger", solidHeader = TRUE, width = 6,
              plotlyOutput("scatter_gdp", height = 360)),
          box(title = "Viz 2: Profit Contribution by Country (waterfall)",
              status = "danger", solidHeader = TRUE, width = 6,
              plotlyOutput("waterfall_profit", height = 360))
        ),
        fluidRow(
          box(title = "Viz 3: Margin vs Inflation Over Time (set focus country in sidebar)",
              status = "danger", solidHeader = TRUE, width = 12,
              plotlyOutput("line_focus", height = 340))
        ),
        fluidRow(
          box(title = "Viz 4: Unemployment vs Sales (colour = margin, size = |margin|)",
              status = "danger", solidHeader = TRUE, width = 6,
              plotlyOutput("bubble_unemp", height = 360)),
          box(title = "Viz 5: Profit by Sub-Category",
              status = "danger", solidHeader = TRUE, width = 6,
              plotlyOutput("bar_subcat", height = 360))
        )
      )
    )
  )
)

#  Server 
server <- function(input, output, session) {

  observeEvent(input$country_all,
    updateCheckboxGroupInput(session, "country", selected = country_volume))
  observeEvent(input$country_none,
    updateCheckboxGroupInput(session, "country", selected = character(0)))
  observeEvent(input$subcat_all,
    updateCheckboxGroupInput(session, "subcat", selected = all_subcats))
  observeEvent(input$subcat_none,
    updateCheckboxGroupInput(session, "subcat", selected = character(0)))

  filtered <- reactive({
    df <- master
    df <- df[df$Country %in% input$country, ]
    df <- df[df$Year >= input$year[1] & df$Year <= input$year[2], ]
    df <- df[df$Sub.Category %in% input$subcat, ]
    df
  })

  output$kpi_sales <- renderValueBox(
    valueBox(dollar(sum(filtered()$Sales, na.rm = TRUE)), "Total Sales",
             icon = icon("dollar-sign"), color = "blue"))
  output$kpi_profit <- renderValueBox({
    p <- sum(filtered()$Profit, na.rm = TRUE)
    valueBox(dollar(p), "Total Profit", icon = icon("chart-line"),
             color = if (p < 0) "red" else "green")
  })
  output$kpi_margin <- renderValueBox({
    s <- sum(filtered()$Sales, na.rm = TRUE); p <- sum(filtered()$Profit, na.rm = TRUE)
    m <- if (s > 0) p / s * 100 else 0
    valueBox(paste0(round(m, 1), "%"), "Profit Margin", icon = icon("percent"),
             color = if (m < 0) "red" else "green")
  })
  output$kpi_discount <- renderValueBox(
    valueBox(paste0(round(mean(filtered()$Discount, na.rm = TRUE) * 100, 1), "%"),
             "Avg Discount", icon = icon("tags"), color = "yellow"))

  output$scatter_gdp <- renderPlotly({
    d <- filtered() %>%
      group_by(Country) %>%
      summarise(gdp = mean(GDP_per_Capita, na.rm = TRUE),
                disc = mean(Discount, na.rm = TRUE) * 100,
                profit = sum(Profit, na.rm = TRUE), .groups = "drop") %>%
      filter(!is.na(gdp))
    validate(need(nrow(d) > 0, "Select at least one country."))
    d$flag <- ifelse(d$Country %in% c("Turkey", "Kazakhstan", "Lithuania"),
                     "Heavy discounter", "Other")
    p <- ggplot(d, aes(gdp, disc, colour = flag, text = paste0(
          Country, "\nGDP/cap: $", comma(round(gdp)),
          "\nAvg discount: ", round(disc, 1), "%"))) +
      geom_point(size = 3, alpha = 0.85) +
      scale_colour_manual(values = c("Heavy discounter" = "#d32f2f", "Other" = "#888888")) +
      scale_x_continuous(labels = dollar) +
      labs(x = "GDP per Capita (PPP)", y = "Average Discount (%)", colour = NULL) +
      theme_minimal()
    lock_plot(ggplotly(p, tooltip = "text"))
  })

  output$waterfall_profit <- renderPlotly({
    d <- filtered() %>%
      group_by(Country) %>%
      summarise(profit = sum(Profit, na.rm = TRUE), .groups = "drop") %>%
      arrange(desc(profit))
    validate(need(nrow(d) > 0, "Select at least one country."))
    p <- plot_ly(type = "waterfall",
            x = d$Country, y = d$profit,
            measure = rep("relative", nrow(d)),
            decreasing = list(marker = list(color = "#d32f2f")),
            increasing = list(marker = list(color = "#388e3c")),
            totals = list(marker = list(color = "#1976d2"))) %>%
      layout(xaxis = list(title = "", tickangle = -45),
             yaxis = list(title = "Profit contribution ($)"))
    lock_plot(p)
  })

  output$line_focus <- renderPlotly({
    d <- master %>%
      filter(Country == input$focus,
             Year >= input$year[1], Year <= input$year[2]) %>%
      group_by(Year) %>%
      summarise(margin = ifelse(sum(Sales) > 0, sum(Profit) / sum(Sales) * 100, NA),
                inflation = mean(Inflation_Rate, na.rm = TRUE), .groups = "drop")
    validate(need(nrow(d) > 0, "No data for this country/year range."))
    p <- plot_ly(d, x = ~Year) %>%
      add_trace(y = ~margin, name = "Profit Margin (%)", type = "scatter",
                mode = "lines+markers", line = list(color = "#d32f2f", width = 3)) %>%
      add_trace(y = ~inflation, name = "Inflation (%)", type = "scatter",
                mode = "lines+markers", yaxis = "y2",
                line = list(color = "#1976d2", width = 3, dash = "dot")) %>%
      layout(title = paste0(input$focus, ": Margin vs Inflation"),
             margin = list(l = 70, r = 90, t = 50, b = 70),
             xaxis = list(title = "Year", dtick = 1),
             yaxis = list(title = list(text = "Profit Margin (%)", standoff = 15),
                          automargin = TRUE),
             yaxis2 = list(title = list(text = "Inflation (%)", standoff = 15),
                           overlaying = "y", side = "right",
                           showgrid = FALSE, automargin = TRUE),
             legend = list(x = 0.05, y = -0.25, orientation = "h"))
    lock_plot(p)
  })

  output$bubble_unemp <- renderPlotly({
    d <- filtered() %>%
      group_by(Country) %>%
      summarise(unemp = mean(Unemployment_Rate, na.rm = TRUE),
                sales = sum(Sales, na.rm = TRUE),
                margin = ifelse(sum(Sales) > 0, sum(Profit) / sum(Sales) * 100, 0),
                .groups = "drop") %>%
      filter(!is.na(unemp))
    validate(need(nrow(d) > 0, "Select at least one country."))
    d$bub <- abs(d$margin) * 0.35 + 8   # marker diameter in px
    p <- plot_ly(d, x = ~unemp, y = ~sales,
            type = "scatter", mode = "markers",
            marker = list(size = ~bub, sizemode = "diameter",
                          color = ~margin, cmid = 0,
                          colorscale = list(c(0, "#d32f2f"),
                                            c(0.5, "#f5f5f5"),
                                            c(1, "#388e3c")),
                          showscale = TRUE,
                          colorbar = list(title = "Margin %"),
                          line = list(width = 1, color = "#555")),
            text = ~paste0(Country, "\nUnemployment: ", round(unemp, 1),
                           "%\nSales: $", comma(sales),
                           "\nMargin: ", round(margin, 1), "%"),
            hoverinfo = "text") %>%
      layout(xaxis = list(title = "Unemployment Rate (%)"),
             yaxis = list(title = "Total Sales ($)"))
    lock_plot(p)
  })

  output$bar_subcat <- renderPlotly({
    d <- filtered() %>%
      group_by(Sub.Category) %>%
      summarise(profit = sum(Profit, na.rm = TRUE), .groups = "drop") %>%
      arrange(profit)
    validate(need(nrow(d) > 0, "Select at least one sub-category."))
    d$Sub.Category <- factor(d$Sub.Category, levels = d$Sub.Category)
    p <- ggplot(d, aes(profit, Sub.Category,
                       fill = profit < 0,
                       text = paste0(Sub.Category, "\nProfit: $", comma(round(profit))))) +
      geom_col() +
      scale_fill_manual(values = c("FALSE" = "#388e3c", "TRUE" = "#d32f2f"), guide = "none") +
      scale_x_continuous(labels = dollar) +
      labs(x = "Total Profit ($)", y = NULL) +
      theme_minimal()
    lock_plot(ggplotly(p, tooltip = "text"))
  })
}

shinyApp(ui, server)
