local date_table = os.date("*t")
local ms = string.match(tostring(os.clock()), "%d%.(%d+)")
local hour, minute, second = date_table.hour, date_table.min, date_table.sec
local year, month, day = date_table.year, date_table.month, date_table.day
local datetime = string.format("%d-%d-%d %d:%d:%d", year, month, day, hour, minute, second)


local http=require("socket.http")
local json = require "json"
local body = http.request("http://192.168.2.53:8080/PCS/survey/getSurveyDetails?username=admin&password=admiN123!&dn=0300")
local api = json.decode(body)


surveyid = api.surveyId
surveyname=api.surveyName
serviceid = api.serviceId 
dn = api.serviceDn -- dial number
questiontype = api.questionsType --it return 1 for boolean and 0 for rating
count = api.questionsCount --count how many questions in api
welcome = api.welcomePrompt --welcome promt
goodbye = api.goodbyePrompt -- goodbye prompt
rating_range = api.ratingRange -- rating range 0 = 1-5 rating and 1 = 0-9 rating
surveytype = api.surveyType -- 0=rating , 1 = boolean , 2 = mix , 3 = mcqs
channel = api.channel  -- return 1 for sms and 0 for voice channel

------------------------get agent id -------------
agentid = session:getVariable("cc_agent");
freeswitch.consoleLog("INFO", "agent info : "..agentid.."\n")
--------------------------------------------------

if api ~= nil then
    goto activesurvey
else
    goto noactivesurvey
end
::activesurvey::

if channel == 0 then 
    session:streamFile("/usr/local/freeswitch/sounds/"..welcome)
    session:sleep(2000);
    goto voicesurvey
else 
end


::voicesurvey::


if api.npsQuestionId == nil then
    npsquestionid = 0
    freeswitch.consoleLog("INFO", "npscheckkkkkkkkkkkkkkkkkkkkkkkkkkk\n")
else
    npsquestionid = api.npsQuestionId
end


questionid = {}
qresult = {}
for i = 1, count ,1 do
    
    promt = api['question'..i..'prompt']
    qtype =api['question'..i..'Type']
    qid =api['question'..i..'Id']
    questionid[i] = qid
    maxtries = 0
    if qtype == 0 then
        if rating_range == 1 then
             ::rating05::
             result = session:playAndGetDigits(1, 1, 1, 3000, "#", "/usr/local/freeswitch/sounds/"..promt.."", "", "\\d+");
             session:sleep(2000);
             qresult[i] = result
             if maxtries == 2 then
                goto nextquestion
             end
             if tonumber(result) == nil or tonumber(result)>9 then
                 maxtries = maxtries+1
                 -- please enter a valid input promt
                 if maxtries < 2 then
                     goto rating05
                 end
             end
        elseif rating_range == 0 then
              ::rating09::
             result = session:playAndGetDigits(1, 1, 1, 3000, "#", "/usr/local/freeswitch/sounds/"..promt.."", "", "\\d+");
             session:sleep(2000);
             qresult[i] = result
             if maxtries == 2 then
                goto nextquestion
             end
             if tonumber(result) == nil or tonumber(result) > 5 or tonumber(result) < 1 then
                 maxtries = maxtries+1
                 -- please enter a valid input promt
                 if maxtries < 2 then
                     goto rating09
                 end
             end
        end


        
        --session:streamFile("/usr/local/freeswitch/sounds/"..cc..".wav");
        --if questiontype == 1 then
        --result = session:playAndGetDigits(1, 1, 2, 3000, "#", "/usr/local/freeswitch/sounds/"..cc..".wav", "", "\\d+");
        --if result>2 then
        --goto again
        --else

    elseif qtype == 1  then
        for i = 1, count ,1 do
            ::booleanrating::
            result = session:playAndGetDigits(1, 1, 1, 3000, "#", "/usr/local/freeswitch/sounds/"..promt.."", "", "\\d+");
            session:sleep(2000);
            qresult[i] = result
            if maxtries == 2 then
                goto nextquestion
             end
            if tonumber(result) == nil or tonumber(result) > 2 or tonumber(result) < 1 then
                maxtries = maxtries+1
                --please enter a vaild promt
                if maxtries < 2 then
                  goto booleanrating
                end

            end
        end

    end
    ::nextquestion::
    freeswitch.consoleLog("INFO", "question dtmf no. '"..i.."output"..qresult[i].."\n")
    
end


npsdigits = nil
npsmaxtries = 0
if (npsquestionid > 0) then
     ::nps_queue::
     npsdigits = session:playAndGetDigits(1, 2, 1, 3000, "#", "/usr/local/freeswitch/sounds/"..npsQuestionPrompt.."", "", "\\d+"); 
     session:sleep(2000);
     if tonumber(npsdigits) == nil or tonumber(npsdigits) >= 10  then
        maxtries = maxtries + 1 
         --flag_head is true
         if maxtries < 2 then
            goto nps_queue
        end
         --nps_answer_value = npsdigits
    end
end

 if api ~= nil then
    session:streamFile("/usr/local/freeswitch/sounds/"..goodbye)
    goto feedback
 end


::noactivesurvey::
--terminate call
session:streamFile("/usr/local/freeswitch/sounds/"..goodbye)
session:sleep(2000);
session:hangup();

----------------------------------------------------------------------
::feedback::       
    --customer number "ani": "1211",
    --"agentId": "101",    "callbackId": 101,    "npsQuestionId": 101, 
    
    ---------post api----------------
    local http = require "socket.http"
    local ltn12 = require "ltn12"
    local json = require "dkjson"
    
    local request_body = { username= "admin",
    password= "admiN123!",
    ani= "5551",
    surveyId= surveyid,
    serviceId= serviceid,
    serviceDn= dn,
    agentId= "101",
    agentName= "John",
    callbackId= 101,
    feedbackTime= datetime,
    question1Id= questionid[1],
    answer1Value= qresult[1],
    question2Id= questionid[2],
    answer2Value= qresult[2],
    question3Id= questionid[3],
    answer3Value= qresult[3],
    question4Id= questionid[4],
    answer4Value= qresult[4],
    question5Id= questionid[5],
    answer5Value= qresult[5],
    question6Id= questionid[6],
    answer6Value= qresult[6],
    question7Id= questionid[7],
    answer7Value= qresult[7],
    question8Id= questionid[8],
    answer8Value= qresult[8],
    question9Id= questionid[9],
    answer9Value= qresult[9],
    npsQuestionId= npsquestionid,
    npsAnswerValue= npsdigits } --the json body
    local response_body = {}
    request_body = json.encode(request_body)
    
    local r, c, h, s = http.request {
      url = 'http://192.168.2.53:8080/PCS/survey/updateFeedback',
      method = 'POST',
      headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = string.len(request_body)
      },
      source = ltn12.source.string(request_body),
      sink = ltn12.sink.table(response_body)
    }
    ---------------------------------------------
         --return "exit";
         freeswitch.consoleLog("INFO", "helooooooooooooooooooooooooooooooooooooo\n")
         freeswitch.consoleLog("INFO", "helooooooooooooooooooooooooooooooooooooo     "..type(questionid[1]).."  "..type(qresult[1]).."  "..type(agentid).."\n")


    

 
 