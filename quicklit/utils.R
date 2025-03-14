library(stringr)
library(httr)
library(WikidataQueryServiceR)
library(tidyr)
library(ggplot2)

plot_author_complenetess_stack_bar <- function(author_qid){
  tidy_result <- get_author_completeness(author_qid)
  tidy_result$name <- factor(tidy_result$name,
                             levels=c("coauthors", "coauthor_strings"),
                             labels=c("Coauthors reconciled", "Coauthors still as strings"))
  p <- ggplot(tidy_result,aes(x=value,y=authorLabel,fill=name))+
    geom_bar(stat="identity", position=position_stack(reverse = TRUE))+
    ggtitle("Author completeness ") +
    theme_minimal() +
    theme(legend.position="bottom",
          legend.title=element_blank(),
          axis.title=element_blank(),
          axis.text.y=element_blank(),
          axis.ticks.y=element_blank(),
          axis.text.x=element_text(size=20),
          legend.text = element_text(size=12)) + 
    labs(fill="")  + 
    scale_fill_manual(values=c("seagreen", "wheat3"))
  
  return(p)
}




#' get_author_completeness
#'
#' Gets a dataframe that indicates how complete the information
#' about an author is on Wikidata
#'
#' @param author_qid
#' @return data.frame
get_author_completeness <- function(author_qid) {
  query = paste0(
    '
  SELECT
?authorLabel
(COUNT(DISTINCT ?item) as ?coauthors)
(COUNT(DISTINCT ?string) as ?coauthor_strings)
WHERE {
   VALUES ?author {wd:',
    author_qid ,
    '}.
   ?article wdt:P50 wd:',
    author_qid ,
    '.
   ?article wdt:P50 ?item.
   ?article wdt:P2093 ?string.
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
GROUP BY ?authorLabel
')
  
  query_result <- query_wikidata(query)
  tidy_result = tidyr::pivot_longer(query_result,
                                    cols  =  c("coauthors",
                                               "coauthor_strings")
  )
    return(tidy_result)
}


#' add_links_to_article_df
#'
#' takes an article_df and adds links
#' @param article_df
#' @return data.frame
#'
add_links_to_article_df <- function(articles_df) {
  qids <- c()
  for (u in articles_df[["item"]])
  {
    qid <- str_replace(u, "http://www.wikidata.org/entity/", "")
    qids <- c(qids, qid)
  }
  articles_df[["item"]] <- NULL
  articles_df[["Tabernacle"]] <-
    prepare_html_tags(qids, "tabernacle")
  articles_df[["Author Disambiguator"]] <-
    prepare_html_tags(qids, "author_disambiguator")
  articles_df[["Scholia"]] <- prepare_html_tags(qids, "scholia")
  return(articles_df)
}


#' prepare_html_tags
#'
#' Prepares the html tags based on a list of qids
#'
#'  @param qids A vector containing qids
#'  @param resource The resource to prepare the tags to. One of c("tabernacle",
#'  "author_disambiguator", "scholia", "wikidata")
prepare_html_tags <- function(qids, resource) {
  if (resource == "tabernacle") {
    name = "add topics"
  } else if (resource == "author_disambiguator") {
    name = "tag authors"
  } else if (resource == "scholia") {
    name = "see profile"
  } else if (resource == "wikidata") {
    name = "Wikidata"
  }
  
  links <- c()
  for (qid in qids)
  {
    ref = prepare_url(qid, resource)
    link <-
      paste0('<a target="_blank" href=', ref, ">", name, "</a>")
    links <- c(links, link)
  }
  
  return(links)
}


#' prepare_url
#'
#' Prepares the link for a resource based on an wikidata qid for an artilce
#'
#' @param qid The wikidata wid
#' @param resource The resource to prepare the url to. One of c("tabernacle",
#'  "author_disambiguator", "scholia", "wikidata")
prepare_url <- function(qid, resource) {
  if (resource == "tabernacle") {
    ref = paste0("https://tabernacle.toolforge.org/?#/tab/manual/",
                 qid,
                 "/P921%3BP4510")
  } else if (resource == "author_disambiguator") {
    ref = paste0(
      "https://author-disambiguator.toolforge.org/work_item_oauth.php?id=",
      qid,
      "&batch_id=&match=1&author_list_id=&doit=Get+author+links+for+work"
    )
  } else if (resource == "scholia") {
    ref = paste0("https://scholia.toolforge.org/work/", qid)
  } else if (resource == "wikidata") {
    ref = paste0("http://www.wikidata.org/entity/", qid)
  }
  
  return(ref)
}




#' @param query The type of query, one of c("covid", "covid_brazil", "bioinfo_brazil")
prepare_dataset_for_page <- function(query = "covid") {
  if (query == "covid") {
    articles_df <- get_covid_df()
  } else if (query == "covid_brazil") {
    articles_df <- get_covid_brazil_df()
  }  else if (query == "bioinfo_brazil") {
    articles_df <- get_brazil_bioinformatics_df()
  }
  articles_df <- add_links_to_article_df(articles_df)
  
  return(articles_df)
}




# SPARQL Query functions -----------------------

#' get_articles_for_canities_project
#'
#' Return the articles within the scope of the Canities project.
#' @param limit The limit of the SPARQL query. Defaults to 6.
get_articles_for_canities_project <- function(limit = 6) {
  topics_of_interest <- c(
    "Q10509939",
    # gray hair
    "Q6933946",
    # white hair
    "Q105566932",
    # hair graying
    "Q48996667" # premature graying of hair
    )
    
    values = "VALUES ?subject {"
    
    for (topic in topics_of_interest) {
      values = paste0(values, "wd:", topic, " ")
    }
    
    values = paste0(values, "}.")
    
    count_query = paste0(
      '
SELECT (COUNT (DISTINCT ?item) as ?count) WHERE {
  ',
      values ,
      '
  ?item wdt:P921 ?subject.
  ?item wdt:P2093 ?author_name_string.
}
')
    
    count <-
      query_wikidata(count_query)[["count"]]
    
    if (count >  6)
    {
      magic_number = round(runif(1, min = 0, max = count  -  6))
      
    } else
    {
      magic_number = 0
    }
    
    query = paste0(
      '
SELECT DISTINCT ?item ?label WHERE {
  ',
      values ,
      '
  ?item wdt:P921 ?subject.
  ?item wdt:P2093 ?author_name_string.
  ?item rdfs:label ?label.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ', magic_number, ' LIMIT ', as.character(limit)
    )
    articles_df <- query_wikidata(query)
    
    articles_df <-
      add_links_to_article_df(articles_df)
    
    return(articles_df)
}








get_brazil_bioinformatics_df <- function(limit = 6) {
  magic_number = round(runif(1, min = 1, max = 3000))
  query = paste0(
    '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P50 ?author.
  {?author wdt:P108 | wdt:P1416 ?institution.
  ?institution wdt:P17 wd:Q155.
  ?institution wdt:P101 wd:Q128570.}
  UNION
  {?author wdt:P108 | wdt:P1416 ?institution.
  ?institution wdt:P17 wd:Q155.
  ?author wdt:P101 wd:Q128570.}
  ?item rdfs:label ?label.
  ?item wdt:P2093 ?author_name_string.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ',
magic_number,
' LIMIT ',
as.character(limit),
'
'
  )
  articles_df <- query_wikidata(query)
  return(articles_df)
  
}

#' get_articles_by_topic
#'
#' Return the articles with at least 1 author string to fill
#' that have a specific main subject.
#'
#' @param subject_qid The qid for the institution of interest
#' @param limit The limit of the SPARQL query. Defaults to 6.
get_articles_by_topic <- function(subject_qid, limit = 6) {
  count_query = paste0(
    '
SELECT (COUNT (DISTINCT ?item) as ?count) WHERE {
  ?item wdt:P921 wd:',
    subject_qid,
    '.
  ?item wdt:P2093 ?author_name_string.
}
')
  
  count <- query_wikidata(count_query)[["count"]]
  
  if (count >  6)
  {
    magic_number = round(runif(1, min = 0, max = count  -  6))
    
  } else
  {
    magic_number = 0
  }
  
  query = paste0(
    '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P921 wd:',
    subject_qid,
    '.
  ?item wdt:P2093 ?author_name_string.
  ?item rdfs:label ?label.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ', magic_number, ' LIMIT ', as.character(limit)
  )
  articles_df <- query_wikidata(query)
  
  articles_df <- add_links_to_article_df(articles_df)
  
  return(articles_df)
}













#' get_articles_by_institution
#'
#' Return the articles with at least 1 author string to fill.
#'
#' @param institution_qid The qid for the institution of interest
#' @param limit The limit of the SPARQL query. Defaults to 6.
get_articles_by_institution <-
  function(institution_qid, limit = 6) {
    count_query = paste0(
      '
SELECT (COUNT (DISTINCT ?item) as ?count) WHERE {
  ?item wdt:P50 ?author.
  ?author wdt:P108 | wdt:P1416 wd:',
      institution_qid,
      '.
  ?item wdt:P2093 ?author_name_string.
}
')
    
    count <- query_wikidata(count_query)[["count"]]
    
    if (count >  6)
    {
      magic_number = round(runif(1, min = 0, max = count  -  6))
      
    } else
    {
      magic_number = 0
    }
    
    query = paste0(
      '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P50 ?author.
  ?author wdt:P108 | wdt:P1416 wd:',
      institution_qid,
      '.
  ?item wdt:P2093 ?author_name_string.
  ?item rdfs:label ?label.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ', magic_number, ' LIMIT ', as.character(limit)
    )
    articles_df <- query_wikidata(query)
    
    articles_df <- add_links_to_article_df(articles_df)
    
    return(articles_df)
  }





#' get_articles_by_author
#'
#' Return the articles with at least 1 author string to fill.
#'
#' @param author_qid The qid for the author of interest
#' @param limit The limit of the SPARQL query. Defaults to 6.
get_articles_by_author <- function(author_qid, limit = 6) {
  count_query = paste0(
    '
SELECT (COUNT (DISTINCT ?item) as ?count) WHERE {
  ?item wdt:P50 wd:',
    author_qid,
    '.
  ?item wdt:P2093 ?author_name_string.
}
')
  
  count <- query_wikidata(count_query)[["count"]]
  
  if (count >  6)
  {
    magic_number = round(runif(1, min = 0, max = count  -  6))
    
  } else
  {
    magic_number = 0
  }
  
  query = paste0(
    '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P50 wd:',
    author_qid,
    '.
  ?item rdfs:label ?label.
  ?item wdt:P2093 ?author_name_string.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ', magic_number, ' LIMIT ', as.character(limit)
  )
  articles_df <- query_wikidata(query)
  
  articles_df <- add_links_to_article_df(articles_df)
  
  return(articles_df)
}




get_covid_brazil_df <- function(limit = 6) {
  magic_number = round(runif(1, min = 1, max = 300))
  query = paste0(
    '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P921 wd:Q84263196.
  ?item wdt:P50 ?author.
  ?author wdt:P108 | wdt:P1416 ?institution.
  ?institution wdt:P17 wd:Q155.
  ?item rdfs:label ?label.
  ?item wdt:P2093 ?author_name_string.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ',
magic_number,
' LIMIT ',
as.character(limit),
'
'
  )
  articles_df <- query_wikidata(query)
  
  return(articles_df)
}

get_covid_df <- function(limit = 6) {
  magic_number = round(runif(1, min = 1, max = 10000))
  query = paste0(
    '
SELECT DISTINCT ?item ?label WHERE {
  ?item wdt:P921 wd:Q84263196.
  ?item rdfs:label ?label.
  ?item wdt:P2093 ?author_name_string.
  FILTER (lang(?label)="en")
}
ORDER BY ?item OFFSET ',
magic_number,
' LIMIT ',
as.character(limit),
'
'
  )
  articles_df <- query_wikidata(query)
  
  return(articles_df)
}
