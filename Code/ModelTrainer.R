?getAccuracy <- function(model, testSet){
  pred <- predict(model, newdata=testSet, type="response")
  class <- round(pred)
  confustionTable <- CrossTable(testSet$churn, class, prop.c=FALSE)$t
  return((confustionTable[1,1]+confustionTable[1,2])/length(y))
}

getLiftMeasure<-function(y, yhat){
  amount <- ceil(length(yhat)/10)
  yhat_sorted <- sort(yhat, decreasing = TRUE, index.return=1)
  inds <- yhat_sorted$ix[1:amount]
  liftMeasure <- (sum(as.numeric(data.ts[inds,]$churn=="bad"))/amount)/0.49562
  return(liftMeasure)
}

ModelPerformance <- function(y, yhat, cutoff=0.5){
  ##Brier Score
  #ynum <- as.numeric(y)-1
  #bs <- (1/length(y))*sum((ynum-yhat)^2)
  
  #Classification Error
  c <- factor(yhat >= cutoff, labels = c("good", "bad"))
  #c <- as.numeric(yhat >= cutoff)
  errorRate <- 1- sum(as.numeric(c == y))/length(y)
  
  return(errorRate)
}

ModelPerformanceByClass <- function(y, yhat){
  errorRate <- 1- sum(as.numeric(yhat == y))/length(y)
  return(errorRate)
}

ctrl <- trainControl(method="cv", number = 10, classProbs = TRUE)

trainNnet <- function(data.tr){
  nnGrid <- expand.grid(size=c(2,5,9), decay=c(.1,1,10))
  nn.tune <- train(churn~., data = data.tr, method="nnet", trControl = ctrl, tuneGrid=nnGrid, trace=FALSE)
  return(nn.tune)
}

trainRandomForest <- function(data.tr){
  rfGrid <- expand.grid(mtry=c(55))
  rf.tune <- train(churn~., data = data.tr, method="parRF", trControl = ctrl, tuneGrid=rfGrid, importance=TRUE)
  return(rf.tune)
}

trainNaiveBayes <- function(data.tr){
  nbGrid <- expand.grid(laplace=c(0,1), useKernel=c("TRUE", "FALSE"))
  bayes.tune <- train(churn~., data = data.tr, method="nb", trControl = ctrl, trace=TRUE)
  return(bayes.tune)
}

trainKNN <- function(data.tr){
  knnGrid <- expand.grid(k=c(3,5,7,9,11,13,15,17))
  knn.tune <- train(churn~., data = data.tr, method="knn", trControl = ctrl, tuneGrid=knnGrid)
  return(knn.tune)
}

trainSVM <- function(data.tr){
  svmGrid <- expand.grid(sigma=c(3,5), C=c(.1, .5, 1, 5, 10, 25))
  svm.tune <- train(churn~., data = data.tr, method="svmRadial", trControl = ctrl)#, tuneGrid=svmGrid)
  return(svm.tune)
}

trainJ48 <- function(data.tr){
  J48Grid <- expand.grid(C=c(0.1,0.2,0.3,0.4,0.5))
  J48.tune <- train(churn~., data = data.tr, method="J48", trControl = ctrl, tuneGrid=J48Grid)
  return(J48.tune)
}

trainAdaBag <- function(data.tr){
  J48Grid <- expand.grid(C=c(0.1,0.2,0.3,0.4,0.5))
  adaBag.tune <- train(churn~., data = data.tr, method="AdaBag", trControl = ctrl)
  return(adaBag.tune)
}

trainLogisticRegression <- function(data.tr){
  bayes.tune <- train(churn~., data = data.tr, method="glm", trControl = ctrl)
  return(bayes.tune)
}

trainGradientBoosting <- function(data.tr){
  gbm <- train(churn~., data = data.tr, method="gbm", trControl = ctrl)
  return(gbm)
}

#Ensemble Random Forest, Logistic Regression and SVMs
library(caretEnsemble)
trainEnsembledMethod <- function(data.tr){
  model_list_big <- caretList(
    churn~., data=data.tr,
    trControl=ctrl,
    metric='ROC',
    tuneList=list(
      rf=caretModelSpec(method='rf', tuneGrid=data.frame(.mtry=c(37,55))),
      svm=caretModelSpec(method='svmRadial'),
      glm=caretModelSpec(method='glm')
    )
  )
  glm_ensemble <- caretStack(
    model_list_big, 
    method='glm',
    metric='ROC',
    trControl=trainControl(
      method='boot',
      number=10,
      savePredictions=TRUE,
      classProbs=TRUE,
      summaryFunction=twoClassSummary
    )
  )
  return(glm_ensemble)
}

trainEnsembledMethod2 <- function(data.tr){
  model_list_big <- caretList(
    churn~., data=data.tr,
    trControl=ctrl,
    metric='ROC',
    tuneList=list(
      rf=caretModelSpec(method='rf', tuneGrid=data.frame(.mtry=c(37,55))),
      svm=caretModelSpec(method='svmRadial'),
      glm=caretModelSpec(method='glm')
    )
  )
  
  greedy_ensemble <- caretEnsemble(model_list_big)
  return(greedy_ensemble)
}

ensembleWrapper <- function(data.tr, data.tr_wo){
  lr <- trainLogisticRegression(data.tr_wo)
  gbm <- trainGradientBoosting(data.tr)
  svm <- trainSVM(data.tr_wo)
  rf <- trainRandomForest(data.tr)
  
  return(list(lr, gbm, svm, rf))
}

predictionWrapper <- function(modelList, newData, newData_wo){
  res <- c(0)
  n <- length(models)
  #lr
  res <- res + predict(modelList[[1]], newdata = newData_wo, type = "prob")$bad
  #gbm
  res <- res + predict(modelList[[2]], newdata = newData, type = "prob")$bad
  #svm
  res <- res + predict(modelList[[3]], newdata = newData_wo, type = "prob")$bad
  #rf
  res <- res + predict(modelList[[4]], newdata = newData, type = "prob")$bad
  
  return(res/n)
}
  