
library (shiny)
library (shinythemes)
library (shinyLP)
library (data.table)
library (tidyverse)
library (xtable)
library (plyr)

openhluttaw <- as.data.frame(read.csv("personId.csv", header = T)[,1:2])
mp_terms  <- as.matrix(read.csv("mp_terms.csv", header = T))
mp_prob <- as.data.frame (read.csv("mp_prob.csv", header = T))
activities <- as.data.frame(read.csv("activities.csv", header = T))

ui <- fluidPage(theme = shinytheme("flatly"),
                titlePanel("Find Your Guy in Hluttaw!"),
                br(),
                textInput("search", "By Your Interest", placeholder = "Topics"),
                br(),
                tableOutput("mp_table")
)

server <- function(input, output) {
  
  output$mp_table <- renderTable({
    InputWordsLocation <- str_locate_all(str_to_lower(input$search), "[a-z,0-9]+") [[1]] #locate all the words and numbers input and igore the rest
    InputWords <- str_sub(input$search, InputWordsLocation[,"start"], InputWordsLocation [,"end"]) #output the located words and numbers
    logicalDF <- matrix (mp_terms %in% InputWords, ncol = 21, byrow = F) #return TRUE for all topic-related words and drop all off-topic words
    if (any(logicalDF)) {
      topicselect <- which(apply (logicalDF, MARGIN = 2, any) == T) 
      multiplyer <- apply (logicalDF [,topicselect,drop = F], MARGIN = 2, sum)
      if (length (topicselect) > 2) {
        
        prob_topic <- sweep (mp_prob [,topicselect], MARGIN = 2, multiplyer, "*")/sum(multiplyer)
      } else {
        prob_topic <- data.frame ((mp_prob [,topicselect]*multiplyer)/sum(multiplyer))
        colnames(prob_topic) <- colnames(mp_prob) [topicselect]
      }
      rank_topic <- rowSums(prob_topic)/ncol (prob_topic)
      concept <- data.frame(cbind(ranks = rank_topic, Ref.No = c(1:995,997:1167)))
      by_topics <- join (activities,concept)
      by_topics <- by_topics %>% group_by(MPID) %>% filter (ranks == max(ranks)) %>% ungroup()
      by_topics <- by_topics [!duplicated(by_topics$MPID),]
      by_topics <- arrange (by_topics, desc(by_topics$ranks))
      
    } else {
      by_topic <- activities
      by_topic <- by_topic [!duplicated(by_topic$MPID),]
    }
    by_topics <- join (by_topics, openhluttaw)
    by_topics <- subset(by_topics, select = c(Name, Constituency, Party, person_id))
    by_topics$person_id <- paste0('http://openhluttaw.info/en_US/person-detail/?personId=', by_topics$person_id)
    by_topics$person_id <- paste0('<a href="',by_topics$person_id,'">',"Make a Call","</a>")
    names(by_topics) [4] <- "Contact"
    xtable(by_topics, caption = "MPs who're most interested in the topic", escape = F)
  }, sanitize.text.function = function(x) x)
}

shinyApp(ui = ui, server = server)

