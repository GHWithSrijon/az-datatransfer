import logging
import os
import azure.functions as func


app = func.FunctionApp()

@app.event_grid_trigger(arg_name="azeventgrid")
def NetappBlobCreateFunction(azeventgrid: func.EventGridEvent):
    event_data = azeventgrid.get_json()  # Access the event data as JSON
    # log os.environ to check if the environment variables are set correctly
    
    logging.info('Environment variables: %s', os.environ)
    logging.info('Python EventGrid trigger processed an event: %s', event_data)
    
