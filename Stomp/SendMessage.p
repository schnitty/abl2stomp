USING Progress.Lang.*.
USING Stomp.*.

ROUTINE-LEVEL ON ERROR UNDO, THROW.

define input parameter MessageData as longchar.
define input parameter HostName as character.
define input parameter PortNumb as integer.
define input parameter UserName as character.
define input parameter UserPass as character.
define input parameter QueueName as character.
define input parameter HeaderData as character.

DEFINE TEMP-TABLE ttHeaders NO-UNDO
  FIELD cHdrData AS CHARACTER EXTENT 2.

define variable okflag as logical.

DEFINE VARIABLE objProducer   AS Stomp.Producer NO-UNDO.
DEFINE VARIABLE objLogger     AS Stomp.Logger   NO-UNDO.

objLogger   = NEW Stomp.Logger("log/producer.log", /* Log file name */
                                                2, /* Max logging entry level */
                                                2  /* Max logging error level */)
.
IF not VALID-OBJECT(objLogger) THEN RETURN "ERROR".
ASSIGN objProducer = NEW Stomp.Producer(QueueName, objLogger, "ErrorHandler", THIS-PROCEDURE).

/* Connect to ActiveMQ server */
IF NOT objProducer:connect(HostName, PortNumb, UserName, UserPass) THEN 
DO:
  RUN CleanUp.
  RETURN "ERROR".
END.

define var i as integer.
do i = 1 to NUM-ENTRIES (HeaderData, "|") by 2:
  CREATE ttHeaders.
  ASSIGN ttHeaders.cHdrData[1] = ENTRY(i,HeaderData, "|").
  ASSIGN ttHeaders.cHdrData[2] = ENTRY(i + 1,HeaderData, "|").
end.

okflag = false.
okflag = objProducer:send(MessageData, TABLE ttHeaders, "cHdrData").

FINALLY:
  RUN CleanUp.
  if okflag then RETURN "OK".
  else RETURN "ERROR".
END.

/*------------------------------------------------------------------------------------------------------------------*/
/*                                                    PROCEDURES                                                    */
/*------------------------------------------------------------------------------------------------------------------*/

/* Clean up heap memory */
PROCEDURE CleanUp:
    IF VALID-OBJECT(objProducer) THEN
      DELETE OBJECT objProducer.
    IF VALID-OBJECT(objLogger) THEN
      DELETE OBJECT objLogger.
    DELETE WIDGET-POOL.
END PROCEDURE.


/* Procedure for handling any errors received from the queue  */
/* (This gets called by the Stomp framework in case of error) */
PROCEDURE ErrorHandler:
  DEFINE INPUT PARAMETER ipiErrorLevel AS INTEGER        NO-UNDO.
  DEFINE INPUT PARAMETER ipcError      AS CHARACTER      NO-UNDO.
  DEFINE INPUT PARAMETER ipobjFrame    AS Stomp.Frame    NO-UNDO.
  
  /* Level 1:    Error:   System shutdown probably best course of action         */
  /* Level 2:  Warning:   System stability may be threatened; should advise user */
  /* Level 3+: Verbose:   Most probably safe to ignore                           */
  
  /* Always log the error info */
  objLogger:writeError(ipiErrorLevel, ipcError).

  /* Dump raw Frame data to log, if available */

  IF ipobjFrame NE ? THEN
    objLogger:dumpFrame(ipobjFrame).
  

  IF ipiErrorLevel LE 2 THEN DO:
    /* Quit program on severe error */
    IF ipiErrorLevel LE 1 THEN DO:
      /* Garbage collection */
      IF VALID-OBJECT(objProducer) THEN
        DELETE OBJECT objProducer.
      IF VALID-OBJECT(objLogger) THEN
        DELETE OBJECT objLogger.
    END. /* IF ipiErrorLevel LE 1 */
  END. /* IF ipiErrorLevel LE 2 */
  ELSE DO: /* ErrorLvl GE 3 */
      /* Do nothing - we will read log file if we are interested */
  END.

END PROCEDURE.
