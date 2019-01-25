
library (shiny)
library (shinythemes)
library (shinyLP)
library (data.table)
library (plyr)
library (tidyverse)
library (xtable)
library (RTextTools)
library (reshape2)


mp_id <- as.data.frame(read.csv("personId.csv", header = T)[,1:2])
mp_table <- readRDS("mp_table.rds")
recordLogs <- as.data.frame(read.csv ("logsRecord.csv"), header = T)
mp_lda <- readRDS("mp_lda.rds")
dw <- readRDS("dw.rds")

topic_func <- function (x,y) {
  x <- join (x, mp_id )
  x <- subset(x, select = c(Name, Constituency, Party, person_id))
  x$person_id <- paste0('http://openhluttaw.info/en_US/person-detail/?personId=', x$person_id)
  x$person_id <- paste0('<a href="',x$person_id,'">',"Make a Call","</a>")
  names(x) [4] <- "Contact"
  x <- x %>% head (y)
  return(x)
}

ui <- fluidPage(theme = shinytheme("flatly"),
                titlePanel("Find Your Guy in Hluttaw!"),
                br(),
                textInput("search", "By Your Interest", placeholder = "Topics"),
                selectInput ("Num", "Number of top champion", choices = list("Top 10" = 10, "Top 15" = 15, "Top 20" = 20, "Top 25" = 25, "Top 30" = 30, "Top 35" = 35, "Top 40" = 40), selected = 20),
                br(),
                tableOutput("mp_table")
)

server <- function(input, output) {
  sessionNo <- recordLogs$session %>% as.numeric(tail(1))+1
  
  output$mp_table <- renderTable({
    
    if (input$search != "") {
      InputWordsLocation <- str_locate_all(str_to_lower(input$search), "[a-z,0-9]+") [[1]]
      InputWords <- str_sub(input$search, InputWordsLocation[,"start"], InputWordsLocation [,"end"])
      InputStem <- wordStem(InputWords)
      matched_inputWords <- which(mp_lda@terms %in% InputStem == T) #Use 'which' for the sake of computation time
      if (any(matched_inputWords) && any (dw %in% InputStem)) {
        if (length(matched_inputWords) > 1) {
          beta_weight <- rowSums(mp_lda@beta[,matched_inputWords])
        } else {
          beta_weight <- mp_lda@beta[,matched_inputWords]
        }
        topic_rank <- factor (c(1:mp_lda@k), c(1:mp_lda@k)[order(beta_weight, decreasing = T)])
        gamma_topics <- cbind(setNames(data.frame(mp_lda@gamma), 1:mp_lda@k), docs = 1:mp_lda@wordassignments$nrow)
        gamma_topics <- setNames(melt(gamma_topics, id.vars = "docs"), c("docs", "topics", "rank"))
        gamma_topics$topics <- factor (gamma_topics$topics, levels(topic_rank))
        gamma_topics <- gamma_topics %>% arrange (topics, desc(rank))
        
        by_topics <- right_join(mp_table,gamma_topics) 
        by_topics <- by_topics %>% arrange (topics, desc(rank))
        by_topics <- by_topics[!duplicated(by_topics$MPID),] #remove duplicated only AFTER arranging, or may cause information loss.
        by_topics <- topic_func (by_topics, input$Num)
        
      } else {
        by_topics <- data.frame(result = "There is no topic related to your input, try again!")
      }
      logsRecord <- data.frame(session = sessionNo, time = Sys.time(), input = paste(InputWords,collapse = " "))
      write.table (logsRecord, "logsRecord.csv", row.names = F, append = T, col.names = F, sep = ",")
    }
    else {
      by_topics <- mp_table 
      by_topics <- by_topics [!duplicated(by_topics$MPID),]
      by_topics <- topic_func(by_topics, input$Num)
    }
    xtable(by_topics, caption = "MPs who're most interested in the topic", escape = F)
  }, sanitize.text.function = function(x) x)
  
}

shinyApp(ui = ui, server = server)

