#' Get survey data
#'
#' Get a participant's responses.
#'
#' @param custom_id A unique identifier for the survey's respondents. NULL by
#'   default, and the built-in {shinysurveys} userID will be used.
#' @param include_dependencies LOGICAL: TRUE (default) and all dependency
#'   questions will be returned, regardless of if the individual respondent saw
#'   it. For respondents who did not see a specific question, the 'response'
#'   will take on the value from the `dependency_string` argument. If FALSE, the
#'   output will have variable rows depending on which questions a given
#'   participant answered.
#' @param dependency_string A character string to be imputed for dependency
#'   questions that a respondent did not see. Default is "HIDDEN-QUESTION".
#'
#' @return A data frame with four columns containing information about the
#'   participant's survey responses: The 'subject_id' column can be used for
#'   identifying respondents. By default, it utilizes shinysurveys URL-based
#'   user tracking feature. The 'question_id' and 'question_type' columns
#'   correspond to  'input_id' and 'input_type' from the original data frame of
#'   questions. The 'response' column is the participant's answer.
#'
#'   The number of rows, corresponding to the questions an individual saw,
#'   depends on the `include_dependencies` argument. If TRUE, by default, then
#'   the resulting data frame will have one row per unique input ID. If FALSE,
#'   the data frame may have variable length depending on which questions a
#'   given individual answers.
#'
#' @export
#'
#' @examples
#'
#' if (interactive()) {
#'
#'  library(shiny)
#'
#'  ui <- fluidPage(
#'    surveyOutput(teaching_r_questions)
#'  )
#'
#'  server <- function(input, output, session) {
#'    renderSurvey()
#'    # Upon submission, print a data frame with participant responses
#'    observeEvent(input$submit, {
#'      print(getSurveyData())
#'    })
#'  }
#'
#'  shinyApp(ui, server)
#'
#'  }
#'
getSurveyData <- function(custom_id = NULL, include_dependencies = TRUE, dependency_string = "HIDDEN-QUESTION") {

  session <- shiny::getDefaultReactiveDomain()

  # get id of instructions input types to exclude from survey response collection
  instructions_id <- survey_env$question_df[which(survey_env$question_df$input_type == "instructions"), "input_id", drop = FALSE]$input_id
  shown_questions <- unique(survey_env$question_df$input_id[which(!survey_env$question_df$input_id %in% instructions_id)])

  for (i in seq_along(survey_env$unique_questions)) {
    survey_env$unique_questions[[i]]$question_number <- rep(i, nrow(survey_env$unique_questions[[i]]))
  }
  #print("unique questions")
  #print(str(survey_env$unique_questions))

  survey_env$ordered_question_df <- do.call(rbind, survey_env$unique_questions)
  print("ordered df")
  print(str(survey_env$ordered_question_df))

  shown_subset <- survey_env$ordered_question_df[which(survey_env$ordered_question_df$input_id %in% shown_questions),]
  shown_input_types <- do.call(rbind,
                               lapply(
                                 split(shown_subset, factor(shown_subset$input_id, levels = unique(shown_subset$input_id))),
                                 function(x) x[1,"input_type", drop = FALSE]$input_type)
  )

  responses <- do.call(rbind,
                      lapply(
                        shown_questions, function(x) {
                          data.frame(response = check_length(.input = session$input[[x]]))
                        }
                      ))
  print("responses")
  print(str(responses))

  output <- make_survey_response_df(.question_id = shown_questions,
                                    .question_type = shown_input_types,
                                    .response = responses)

  print("output")
  print(str(output))

  # paste here


  if (!is.null(custom_id)) {
    output <- cbind(subject_id = custom_id,
                    output)
  } else if (is.null(custom_id)) {
    output <- cbind(subject_id = session$input$userID,
                    output)
  }


  output <- split(output, factor(output$question_id, levels = unique(output$question_id)))
  output <- do.call(rbind, lapply(
    output, function(x) x[1,]
  ))
  rownames(output) <- NULL


  if (include_dependencies) {
    output[which(output$question_id %in% session$input$shinysurveysHiddenInputs), "response"] <- dependency_string
  } else if (!include_dependencies) {
    output <- output[which(!output$question_id %in% session$input$shinysurveysHiddenInputs),]
  }

  splitter <- function(text){
    sapply(str_split(text, ","),str_trim) %>% as.vector()
  }

  #print("output")
  #print(output)
  #print("ordered")
  #print(survey_env$ordered_question_df)


  ordered_df <- survey_env$ordered_question_df
  print("ordered df 2")
  print(str(ordered_df))


  if(nrow(output)>0)
  {
    for(i in 1:nrow(output))
    {
      if(output$question_type[i] == "matrix")
      #if(output$question_type[i] %in% c("matrix", "radiomatrix"))
      {
        myid <- output$question_id[i]


        # Store id index to access dim info
        ordered_index <- which(ordered_df$input_id == myid)
        qrow <- length(splitter(str_split(ordered_df$option[ordered_index],"/")[[1]][1]))
        qcol <- length(splitter(str_split(ordered_df$option[ordered_index],"/")[[1]][2]))

        splitted <- splitter(output$response[i])

        # replace empty cells with NA
        empty <- str_trim(splitted) == ""
        splitted[empty] <- NA

        # format into matrix to then combine
        M <- matrix(splitted, qrow, qcol, byrow=F)
        output$response[i] <-paste(apply(M, 1, paste, collapse=","), collapse=";")
      }

    }

  }





  return(output)

 }

